// glinka
// Copyright (C) 2021 Ollie Etherington
// <www.etherington.xyz>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Config = @import("../common/config.zig").Config;
const Cursor = @import("../common/cursor.zig").Cursor;
const ParseError = @import("../frontend/parse_result.zig").ParseError;
const Parser = @import("../frontend/parser.zig").Parser;
const node = @import("../frontend/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const Backend = @import("../backends/backend.zig").Backend;
const Scope = @import("scope.zig").Scope;
const Type = @import("types/type.zig").Type;
const TypeError = @import("types/type_error.zig").TypeError;
const ImplicitAnyError = @import("types/implicit_any_error.zig").ImplicitAnyError;
const ErrorContext = @import("error_context.zig").ErrorContext;
const CompileError = @import("compile_error.zig").CompileError;
const inferrer = @import("inferrer.zig");

pub const Compiler = struct {
    alloc: *Allocator,
    config: *const Config,
    parser: *Parser,
    backend: *Backend,
    scope: *Scope,
    errors: ErrorContext,

    pub fn new(
        alloc: *Allocator,
        config: *const Config,
        parser: *Parser,
        backend: *Backend,
    ) !Compiler {
        return Compiler{
            .alloc = alloc,
            .config = config,
            .parser = parser,
            .backend = backend,
            .scope = try Scope.new(alloc, null),
            .errors = ErrorContext.new(alloc),
        };
    }

    pub fn deinit(self: *Compiler) void {
        self.scope.deinit();
        self.errors.deinit();
    }

    pub fn hasErrors(self: Compiler) bool {
        return self.errors.count() > 0;
    }

    pub fn reportErrors(self: Compiler) !void {
        try self.errors.report();
    }

    fn implicitAny(self: *Compiler, csr: Cursor, symbol: []const u8) !Type {
        if (self.config.errorOnImplicitAny)
            try self.errors.append(CompileError.implicitAnyError(
                ImplicitAnyError.new(csr, symbol),
            ));

        return Type.newAny();
    }

    fn processDecl(self: *Compiler, nd: Node) !void {
        std.debug.assert(nd.getType() == NodeType.Decl);

        const decl = nd.data.Decl;

        const tyHint = if (decl.ty) |ty|
            try inferrer.findType(self.scope, ty)
        else
            try self.implicitAny(nd.csr, decl.name);

        if (decl.value) |value| {
            const valTy = inferrer.inferExprType(self.scope, value);

            if (!valTy.isAssignableTo(tyHint)) {
                try self.errors.append(CompileError.typeError(
                    TypeError.new(nd.csr, valTy, tyHint),
                ));

                return;
            }
        }

        // TODO Insert into scope

        try self.backend.declaration(nd);
    }

    pub fn processNode(self: *Compiler, nd: Node) !void {
        nd.dump(); // TODO: TMP

        switch (nd.data) {
            .Decl => try self.processDecl(nd),
            else => {},
        }
    }

    pub fn run(self: *Compiler) !void {
        try self.backend.prolog();

        while (true) {
            const res = try self.parser.next();

            const nd = switch (res) {
                .Success => |node| node,
                .Error => |err| {
                    try self.errors.append(CompileError.parseError(err));
                    return;
                },
                .NoMatch => |err| {
                    const theError = if (err) |perr|
                        perr
                    else
                        ParseError.message(
                            self.parser.lexer.csr,
                            "Expected a top-level statement",
                        );

                    try self.errors.append(CompileError.parseError(theError));
                    return;
                },
            };

            switch (nd.getType()) {
                .EOF => break,
                else => try self.processNode(nd),
            }
        }

        try self.backend.epilog();
    }
};
