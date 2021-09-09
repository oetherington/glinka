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
const expectEqualSlices = std.testing.expectEqualSlices;
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const Lexer = @import("lexer.zig").Lexer;
const Cursor = @import("cursor.zig").Cursor;
const node = @import("node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Decl = node.Decl;
const TokenType = @import("token.zig").TokenType;
const parseresult = @import("parse_result.zig");
const ParseResult = parseresult.ParseResult;
const ParseError = parseresult.ParseError;

pub const Parser = struct {
    arena: Arena,
    lexer: Lexer,

    pub fn new(alloc: *Allocator, code: []const u8) Parser {
        var lexer = Lexer.new(code);
        _ = lexer.next();

        return Parser{
            .arena = Arena.init(alloc),
            .lexer = lexer,
        };
    }

    pub fn deinit(self: Parser) void {
        self.arena.deinit();
    }

    fn getAllocator(self: *Parser) *Allocator {
        return &self.arena.allocator;
    }

    fn parsePrimaryExpr(self: *Parser) Allocator.Error!ParseResult {
        const alloc = self.getAllocator();
        const csr = self.lexer.token.csr;

        const nd = try switch (self.lexer.token.ty) {
            .Ident => makeNode(alloc, csr, .Ident, self.lexer.token.data),
            .True => makeNode(alloc, csr, .True, {}),
            .False => makeNode(alloc, csr, .False, {}),
            .Null => makeNode(alloc, csr, .Null, {}),
            .Undefined => makeNode(alloc, csr, .Undefined, {}),
            else => return ParseResult.noMatch(null),
        };

        _ = self.lexer.next();

        return ParseResult.success(nd);
    }

    fn parseExpr(self: *Parser) Allocator.Error!ParseResult {
        return self.parsePrimaryExpr();
    }

    fn parseType(self: *Parser) Allocator.Error!ParseResult {
        switch (self.lexer.token.ty) {
            .Ident => {
                const nd = try makeNode(
                    self.getAllocator(),
                    self.lexer.token.csr,
                    NodeType.TypeName,
                    self.lexer.token.data,
                );

                _ = self.lexer.next();

                return ParseResult.success(nd);
            },
            else => return ParseResult.noMatch(null),
        }
    }

    fn parseDecl(
        self: *Parser,
        comptime ty: NodeType,
    ) Allocator.Error!ParseResult {
        const csr = self.lexer.token.csr;

        const name = self.lexer.next();
        if (name.ty != .Ident)
            return ParseResult.expected(TokenType.Ident, name);

        var declTy: ?Node = null;

        var tkn = self.lexer.next();
        if (tkn.ty == .Colon) {
            _ = self.lexer.next();
            const tyRes = try self.parseType();
            if (!tyRes.isSuccess())
                return tyRes;
            declTy = tyRes.Success;
            tkn = self.lexer.token;
        }

        var expr: ?Node = null;

        if (tkn.ty == TokenType.Eq) {
            _ = self.lexer.next();
            const exprRes = try self.parseExpr();
            if (!exprRes.isSuccess())
                return exprRes;
            expr = exprRes.Success;
            tkn = self.lexer.token;
        }

        if (tkn.ty != TokenType.Semi)
            return ParseResult.expected(TokenType.Semi, self.lexer.token);

        const decl = Decl.new(name.data, declTy, expr);
        const result = try makeNode(self.getAllocator(), csr, ty, decl);

        return ParseResult.success(result);
    }

    fn parseTopLevel(self: *Parser) Allocator.Error!ParseResult {
        return switch (self.lexer.token.ty) {
            .Var => self.parseDecl(.Var),
            .Let => self.parseDecl(.Let),
            .Const => self.parseDecl(.Const),
            else => ParseResult.expected(
                "a top-level statement",
                self.lexer.token,
            ),
        };
    }

    pub fn next(self: *Parser) Allocator.Error!ParseResult {
        return self.parseTopLevel();
    }
};

test "parser can be initialized" {
    const code: []const u8 = "some sample code";
    var parser = Parser.new(std.testing.allocator, code);
    defer parser.deinit();
    try expectEqualSlices(u8, code, parser.lexer.code);
}

test "parser can parse var, let and const declarations" {
    const Runner = struct {
        code: []const u8,
        expectedNodeType: NodeType,
        expectedDeclType: ?Node,
        expectedValueIdent: ?[]const u8,

        fn run(self: @This()) !void {
            var parser = Parser.new(std.testing.allocator, self.code);
            defer parser.deinit();

            const res = try parser.next();

            try expect(res.isSuccess());
            try expectEqual(self.expectedNodeType, res.Success.getType());

            switch (res.Success.data) {
                .Var, .Let, .Const => |d| {
                    try expectEqualSlices(u8, "test", d.name);

                    if (self.expectedDeclType) |t| {
                        try expect(t.eql(d.ty));
                    } else {
                        try expect(d.ty == null);
                    }

                    if (self.expectedValueIdent) |i| {
                        if (d.value) |value| {
                            try expectEqual(NodeType.Ident, value.getType());
                            try expectEqualSlices(u8, i, value.data.Ident);
                        } else {
                            std.debug.panic("Value should not be null", .{});
                        }
                    } else {
                        try expect(d.value == null);
                    }
                },
                else => std.debug.panic("Invalid test result", .{}),
            }
        }
    };

    const numberType = try makeNode(
        std.testing.allocator,
        Cursor.new(1, 11),
        NodeType.TypeName,
        "number",
    );
    defer std.testing.allocator.destroy(numberType);

    try (Runner{
        .code = "var test;",
        .expectedNodeType = NodeType.Var,
        .expectedDeclType = null,
        .expectedValueIdent = null,
    }).run();

    try (Runner{
        .code = "let test;",
        .expectedNodeType = NodeType.Let,
        .expectedDeclType = null,
        .expectedValueIdent = null,
    }).run();

    try (Runner{
        .code = "const test;",
        .expectedNodeType = NodeType.Const,
        .expectedDeclType = null,
        .expectedValueIdent = null,
    }).run();

    try (Runner{
        .code = "var test: number;",
        .expectedNodeType = NodeType.Var,
        .expectedDeclType = numberType,
        .expectedValueIdent = null,
    }).run();

    try (Runner{
        .code = "var test = someOtherVariable;",
        .expectedNodeType = NodeType.Var,
        .expectedDeclType = null,
        .expectedValueIdent = "someOtherVariable",
    }).run();

    try (Runner{
        .code = "var test: number = someOtherVariable;",
        .expectedNodeType = NodeType.Var,
        .expectedDeclType = numberType,
        .expectedValueIdent = "someOtherVariable",
    }).run();
}

test "can parse expressions" {
    const Runner = struct {
        expr: []const u8,
        check: fn (value: Node) anyerror!void,

        pub fn run(comptime self: @This()) !void {
            const code = "var a = " ++ self.expr ++ ";";

            var parser = Parser.new(std.testing.allocator, code);
            defer parser.deinit();

            const res = try parser.next();
            try expect(res.isSuccess());

            const value = res.Success.data.Var.value.?;
            try self.check(value);
        }
    };

    try (Runner{
        .expr = "aVariableName",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Ident, value.getType());
                try expectEqualSlices(u8, "aVariableName", value.data.Ident);
            }
        }).check,
    }).run();

    try (Runner{
        .expr = "true",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.True, value.getType());
            }
        }).check,
    }).run();

    try (Runner{
        .expr = "false",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.False, value.getType());
            }
        }).check,
    }).run();

    try (Runner{
        .expr = "null",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Null, value.getType());
            }
        }).check,
    }).run();

    try (Runner{
        .expr = "undefined",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Undefined, value.getType());
            }
        }).check,
    }).run();
}
