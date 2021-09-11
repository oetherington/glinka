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
const Parser = @import("parser.zig").Parser;
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

const ExprTestCase = struct {
    expr: []const u8,
    check: fn (value: Node) anyerror!void,

    pub fn run(comptime self: @This()) !void {
        const code = "var a = " ++ self.expr ++ ";";

        var parser = Parser.new(std.testing.allocator, code);
        defer parser.deinit();

        const res = try parser.next();
        try expect(res.isSuccess());

        const value = res.Success.data.Var.value.?;
        try expectEqual(Cursor.new(1, 9), value.csr);
        try self.check(value);
    }
};

fn parsePrimaryExpr(psr: *Parser) Allocator.Error!ParseResult {
    const alloc = psr.getAllocator();
    const csr = psr.lexer.token.csr;

    const nd = try switch (psr.lexer.token.ty) {
        .Ident => makeNode(alloc, csr, .Ident, psr.lexer.token.data),
        .String => makeNode(alloc, csr, .String, psr.lexer.token.data),
        .Template => makeNode(alloc, csr, .Template, psr.lexer.token.data),
        .True => makeNode(alloc, csr, .True, {}),
        .False => makeNode(alloc, csr, .False, {}),
        .Null => makeNode(alloc, csr, .Null, {}),
        .Undefined => makeNode(alloc, csr, .Undefined, {}),
        else => return ParseResult.noMatch(null),
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
                try expectEqualSlices(u8, "aVariableName", value.data.Ident);
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

pub fn parseExpr(psr: *Parser) Allocator.Error!ParseResult {
    return parsePrimaryExpr(psr);
}
