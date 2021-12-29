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
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const Config = @import("../common/config.zig").Config;
const Cursor = @import("../common/cursor.zig").Cursor;
const Node = @import("../common/node.zig").Node;
const Backend = @import("../common/backend.zig").Backend;
const Scope = @import("scope.zig").Scope;
const Type = @import("../common/types/type.zig").Type;
const TypeBook = @import("typebook.zig").TypeBook;
const TypeError = @import("errors/type_error.zig").TypeError;
const implicitAnyError = @import("errors/implicit_any_error.zig");
const ImplicitAnyError = implicitAnyError.ImplicitAnyError;
const CompileError = @import("errors/compile_error.zig").CompileError;
const ErrorContext = @import("errors/error_context.zig").ErrorContext;
const inferrer = @import("inferrer.zig");
const typeFinder = @import("type_finder.zig");
const expression = @import("expression.zig");
const block = @import("block.zig");
const declaration = @import("declaration.zig");
const conditional = @import("conditional.zig");
const loop = @import("loop.zig");
const throw = @import("throw.zig");
const function = @import("function.zig");
const allocate = @import("../common/allocate.zig");
const NopBackend = @import("compiler_test_case.zig").NopBackend;

pub const Compiler = struct {
    const StringList = std.ArrayList([]u8);

    alloc: *Allocator,
    config: *const Config,
    backend: *Backend,
    scope: *Scope,
    typebook: *TypeBook,
    errors: ErrorContext,
    strings: StringList,

    pub fn new(
        alloc: *Allocator,
        config: *const Config,
        backend: *Backend,
    ) Compiler {
        return Compiler{
            .alloc = alloc,
            .config = config,
            .backend = backend,
            .scope = Scope.new(alloc, null),
            .typebook = TypeBook.new(alloc),
            .errors = ErrorContext.new(alloc),
            .strings = StringList.init(alloc),
        };
    }

    pub fn deinit(self: *Compiler) void {
        std.debug.assert(self.scope.parent == null);
        self.scope.deinit();

        self.typebook.deinit();

        self.errors.deinit();

        for (self.strings.items) |string|
            self.alloc.free(string);

        self.strings.deinit();
    }

    pub fn pushScope(self: *Compiler) void {
        self.scope = Scope.new(self.alloc, self.scope);
    }

    pub fn popScope(self: *Compiler) void {
        std.debug.assert(self.scope.parent != null);
        var old = self.scope;
        self.scope = old.parent.?;
        old.deinit();
    }

    pub fn hasErrors(self: Compiler) bool {
        return self.errors.count() > 0;
    }

    pub fn reportErrors(self: Compiler) !void {
        try self.errors.reportToStdErr();
    }

    pub fn getError(self: Compiler, index: usize) CompileError {
        return self.errors.list.items[index];
    }

    pub fn fmt(
        self: *Compiler,
        comptime format: []const u8,
        args: anytype,
    ) []u8 {
        const string = std.fmt.allocPrint(
            self.alloc,
            format,
            args,
        ) catch allocate.reportAndExit();
        self.strings.append(string) catch allocate.reportAndExit();
        return string;
    }

    pub fn implicitAny(
        self: *Compiler,
        csr: Cursor,
        symbol: []const u8,
    ) Type.Ptr {
        if (self.config.errorOnImplicitAny)
            self.errors.append(CompileError.implicitAnyError(
                ImplicitAnyError.new(csr, symbol),
            )) catch allocate.reportAndExit();

        return self.typebook.getAny();
    }

    pub fn inferExprType(self: *Compiler, nd: Node) ?Type.Ptr {
        const valTy = inferrer.inferExprType(self, nd);
        switch (valTy) {
            .Success => |ty| {
                nd.ty = ty;
                return ty;
            },
            .Error => |err| {
                self.errors.append(err) catch allocate.reportAndExit();
                return null;
            },
        }
    }

    pub fn findType(self: *Compiler, nd: Node) ?Type.Ptr {
        return typeFinder.findType(self.scope, self.typebook, nd);
    }

    pub fn processNode(self: *Compiler, nd: Node) void {
        switch (nd.data) {
            .PrefixOp,
            .PostfixOp,
            .BinaryOp,
            .Ternary,
            .Ident,
            .True,
            .False,
            .Null,
            .Undefined,
            .Int,
            .String,
            .Call,
            => expression.processExpression(self, nd),
            .Block => block.processBlock(self, nd),
            .Decl => declaration.processDecl(self, nd),
            .If => conditional.processConditional(self, nd),
            .Switch => conditional.processSwitch(self, nd),
            .For => loop.processFor(self, nd),
            .While => loop.processWhile(self, nd),
            .Do => loop.processDo(self, nd),
            .Break => loop.processBreak(self, nd),
            .Continue => loop.processContinue(self, nd),
            .Throw => throw.processThrow(self, nd),
            .Try => throw.processTry(self, nd),
            .Function => function.processFunction(self, nd),
            .Return => function.processReturn(self, nd),
            else => std.debug.panic(
                "Unhandled node type in Compiler.processNode: {?}\n",
                .{nd.getType()},
            ),
        }
    }

    pub fn compileProgramNode(self: *Compiler, nd: Node) !void {
        std.debug.assert(nd.getType() == .Program);

        try self.backend.prolog();

        for (nd.data.Program.items) |child| {
            self.processNode(child);
            if (!self.hasErrors())
                try self.backend.processNode(child);
        }

        try self.backend.epilog();
    }

    pub fn compile(self: *Compiler, driver: anytype, path: []const u8) !void {
        var arena = Arena.init(self.alloc);
        defer arena.deinit();

        const file = try driver.parseFile(&arena, path);

        const nd = switch (file.res) {
            .Success => |node| node,
            .Error => |err| {
                try self.errors.append(CompileError.parseError(err));
                return;
            },
            .NoMatch => std.debug.panic(
                "parseFile should never return NoMatch",
                .{},
            ),
        };

        try self.compileProgramNode(nd);
    }
};

test "can push and pop compiler scopes" {
    const config = Config{};
    var backend = NopBackend.new();

    var compiler = Compiler.new(
        std.testing.allocator,
        &config,
        &backend.backend,
    );
    defer compiler.deinit();

    const first = compiler.scope;
    try expect(first.parent == null);

    compiler.pushScope();

    const second = compiler.scope;
    try expect(first != second);
    try expectEqual(first, second.parent.?);

    compiler.popScope();

    const third = compiler.scope;
    try expectEqual(first, third);
    try expect(third.parent == null);
}
