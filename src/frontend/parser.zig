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
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Decl = node.Decl;
const TokenType = @import("token.zig").TokenType;
const parseresult = @import("parse_result.zig");
const ParseResult = parseresult.ParseResult;
const ParseError = parseresult.ParseError;
const exprParser = @import("expr_parser.zig");

pub const Parser = struct {
    const Error = Allocator.Error;

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

    pub fn getAllocator(self: *Parser) *Allocator {
        return &self.arena.allocator;
    }

    fn parseExpr(self: *Parser) Parser.Error!ParseResult {
        return exprParser.parseExpr(self);
    }

    fn parseType(self: *Parser) Parser.Error!ParseResult {
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
    ) Parser.Error!ParseResult {
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

    fn parseTopLevel(self: *Parser) Parser.Error!ParseResult {
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

    pub fn next(self: *Parser) Parser.Error!ParseResult {
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
