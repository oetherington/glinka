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
const expectEqualStrings = std.testing.expectEqualStrings;
const Allocator = std.mem.Allocator;
const Parser = @import("parser.zig").Parser;
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Decl = node.Decl;
const TokenType = @import("token.zig").Token.Type;
const parseresult = @import("parse_result.zig");
const ParseResult = parseresult.ParseResult;
const ParseError = parseresult.ParseError;

const ExprTestCase = struct {
    expr: []const u8,
    startingCh: u32 = 9,
    check: fn (value: Node) anyerror!void,

    pub fn run(comptime self: @This()) !void {
        const code = "var a = " ++ self.expr ++ ";";

        var parser = Parser.new(std.testing.allocator, code);
        defer parser.deinit();

        const res = try parser.next();
        try res.reportIfError(std.io.getStdErr().writer());
        try expect(res.isSuccess());

        const value = res.Success.data.Decl.value.?;
        try expectEqual(Cursor.new(1, self.startingCh), value.csr);
        try self.check(value);
    }
};

fn parsePrimaryExpr(psr: *Parser) Parser.Error!ParseResult {
    const alloc = psr.getAllocator();
    const csr = psr.lexer.token.csr;

    const nd = try switch (psr.lexer.token.ty) {
        .Ident => makeNode(alloc, csr, .Ident, psr.lexer.token.data),
        .Int => makeNode(alloc, csr, .Int, psr.lexer.token.data),
        .String => makeNode(alloc, csr, .String, psr.lexer.token.data),
        .Template => makeNode(alloc, csr, .Template, psr.lexer.token.data),
        .True => makeNode(alloc, csr, .True, {}),
        .False => makeNode(alloc, csr, .False, {}),
        .Null => makeNode(alloc, csr, .Null, {}),
        .Undefined => makeNode(alloc, csr, .Undefined, {}),
        .This => makeNode(alloc, csr, .This, {}),
        .LParen => {
            _ = psr.lexer.next();
            const expr = try psr.parseExpr();
            if (!expr.isSuccess())
                return expr;
            if (psr.lexer.token.ty != .RParen)
                return ParseResult.expected(TokenType.RParen, psr.lexer.token);
            _ = psr.lexer.next();
            return expr;
        },
        else => return ParseResult.noMatchExpected(
            "a primary expression",
            psr.lexer.token,
        ),
    };

    _ = psr.lexer.next();

    return ParseResult.success(nd);
}

test "can parse variable name primary expression" {
    try (ExprTestCase{
        .expr = "aVariableName",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Ident, value.getType());
                try expectEqualStrings("aVariableName", value.data.Ident);
            }
        }).check,
    }).run();
}

test "can parse int primary expression" {
    try (ExprTestCase{
        .expr = "123456",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Int, value.getType());
                try expectEqualStrings("123456", value.data.Int);
            }
        }).check,
    }).run();
}

test "can parse string primary expression" {
    try (ExprTestCase{
        .expr = "'a test string'",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.String, value.getType());
                try expectEqualStrings("'a test string'", value.data.String);
            }
        }).check,
    }).run();
}

test "can parse template primary expression" {
    try (ExprTestCase{
        .expr = "`a test template`",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Template, value.getType());
                try expectEqualStrings("`a test template`", value.data.Template);
            }
        }).check,
    }).run();
}

test "can parse 'true' primary expression" {
    try (ExprTestCase{
        .expr = "true",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.True, value.getType());
            }
        }).check,
    }).run();
}

test "can parse 'false' primary expression" {
    try (ExprTestCase{
        .expr = "false",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.False, value.getType());
            }
        }).check,
    }).run();
}

test "can parse 'null' primary expression" {
    try (ExprTestCase{
        .expr = "null",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Null, value.getType());
            }
        }).check,
    }).run();
}

test "can parse 'undefined' primary expression" {
    try (ExprTestCase{
        .expr = "undefined",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Undefined, value.getType());
            }
        }).check,
    }).run();
}

test "can parse 'this' primary expression" {
    try (ExprTestCase{
        .expr = "this",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.This, value.getType());
            }
        }).check,
    }).run();
}

test "can parse paren primary expression" {
    try (ExprTestCase{
        .expr = "(123456)",
        .startingCh = 10,
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Int, value.getType());
                try expectEqualStrings("123456", value.data.Int);
            }
        }).check,
    }).run();
}

fn parsePostfixExpr(psr: *Parser) Parser.Error!ParseResult {
    const res = try parsePrimaryExpr(psr);
    if (!res.isSuccess())
        return res;

    var left = res.Success;

    while (true) {
        if (psr.lexer.token.ty == .Inc) {
            left = try makeNode(
                psr.getAllocator(),
                psr.lexer.token.csr,
                .PostfixInc,
                left,
            );
            _ = psr.lexer.next();
        } else if (psr.lexer.token.ty == .Dec) {
            left = try makeNode(
                psr.getAllocator(),
                psr.lexer.token.csr,
                .PostfixDec,
                left,
            );
            _ = psr.lexer.next();
        } else {
            return ParseResult.success(left);
        }
    }
}

test "can parse postfix increment and decrement expressions" {
    try (ExprTestCase{
        .expr = "b++",
        .startingCh = 10,
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.PostfixInc, value.getType());
                const subExpr = value.data.PostfixInc;
                try expectEqual(NodeType.Ident, subExpr.getType());
                try expectEqualStrings("b", subExpr.data.Ident);
            }
        }).check,
    }).run();
}

fn parseBinaryExpr(psr: *Parser) Parser.Error!ParseResult {
    const left = parsePostfixExpr(psr);

    return left;
}

pub fn parseExpr(psr: *Parser) Parser.Error!ParseResult {
    return parseBinaryExpr(psr);
}
