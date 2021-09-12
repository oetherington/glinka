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
const ParseError = @import("../frontend/parse_result.zig").ParseError;
const Parser = @import("../frontend/parser.zig").Parser;
const Node = @import("../frontend/node.zig").Node;
const Backend = @import("../backends/backend.zig").Backend;
const errorContext = @import("error_context.zig");
const ErrorContext = errorContext.ErrorContext;
const CompileError = @import("compile_error.zig").CompileError;

pub const Compiler = struct {
    alloc: *Allocator,
    parser: *Parser,
    backend: *Backend,
    errors: ErrorContext,

    pub fn new(alloc: *Allocator, parser: *Parser, backend: *Backend) Compiler {
        return Compiler{
            .alloc = alloc,
            .parser = parser,
            .backend = backend,
            .errors = ErrorContext.new(alloc),
        };
    }

    pub fn deinit(self: *Compiler) void {
        self.errors.deinit();
    }

    pub fn hasErrors(self: Compiler) bool {
        return self.errors.count() > 0;
    }

    pub fn reportErrors(self: Compiler) !void {
        try self.errors.report();
    }

    pub fn processNode(self: *Compiler, node: Node) !void {
        _ = self;
        node.dump();

        switch (node.data) {
            .Var, .Let, .Const => {
                try self.backend.declaration(node);
            },
            else => {},
        }
    }

    pub fn run(self: *Compiler) !void {
        try self.backend.prolog();

        while (true) {
            const res = try self.parser.next();

            const node = switch (res) {
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

            switch (node.getType()) {
                .EOF => break,
                else => try self.processNode(node),
            }
        }

        try self.backend.epilog();
    }
};
