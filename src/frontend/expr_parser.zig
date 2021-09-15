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
    startingCh: u32 = 0,
    check: fn (value: Node) anyerror!void,

    pub fn run(comptime self: @This()) !void {
        const code = "var a = " ++ self.expr ++ ";";

        var parser = Parser.new(std.testing.allocator, code);
        defer parser.deinit();

        const res = try parser.next();
        try res.reportIfError(std.io.getStdErr().writer());
        try expect(res.isSuccess());

        const value = res.Success.data.Decl.value.?;
        try expectEqual(Cursor.new(1, 9 + self.startingCh), value.csr);
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
        .startingCh = 1,
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
                .PostfixOp,
                node.UnaryOp.new(.Inc, left),
            );
            _ = psr.lexer.next();
        } else if (psr.lexer.token.ty == .Dec) {
            left = try makeNode(
                psr.getAllocator(),
                psr.lexer.token.csr,
                .PostfixOp,
                node.UnaryOp.new(.Dec, left),
            );
            _ = psr.lexer.next();
        } else {
            return ParseResult.success(left);
        }
    }
}

test "can parse postfix unary operator expressions" {
    try (ExprTestCase{
        .expr = "b++",
        .startingCh = 1,
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.PostfixOp, value.getType());
                const data = value.data.PostfixOp;
                try expectEqual(TokenType.Inc, data.op);
                try expectEqual(NodeType.Ident, data.expr.getType());
                try expectEqualStrings("b", data.expr.data.Ident);
            }
        }).check,
    }).run();
}

fn parsePrefixExpr(psr: *Parser) Parser.Error!ParseResult {
    const op = switch (psr.lexer.token.ty) {
        .Delete,
        .Void,
        .TypeOf,
        .Inc,
        .Dec,
        .Add,
        .Sub,
        .BitNot,
        .LogicalNot,
        => psr.lexer.token,
        else => return try parsePostfixExpr(psr),
    };

    _ = psr.lexer.next();

    const expr = try parsePrefixExpr(psr);
    if (!expr.isSuccess())
        return expr;

    return ParseResult.success(try makeNode(
        psr.getAllocator(),
        op.csr,
        .PrefixOp,
        node.UnaryOp.new(op.ty, expr.Success),
    ));
}

test "can parse prefix unary operator expressions" {
    try (ExprTestCase{
        .expr = "++b",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.PrefixOp, value.getType());
                const data = value.data.PrefixOp;
                try expectEqual(TokenType.Inc, data.op);
                try expectEqual(NodeType.Ident, data.expr.getType());
                try expectEqualStrings("b", data.expr.data.Ident);
            }
        }).check,
    }).run();
}

fn BinaryOpParser(
    next: fn (psr: *Parser) Parser.Error!ParseResult,
    tokens: []const TokenType,
) type {
    return struct {
        pub fn parse(psr: *Parser) Parser.Error!ParseResult {
            const res = try next(psr);
            if (!res.isSuccess())
                return res;

            var left = res.Success;

            opLoop: while (true) {
                inline for (tokens) |tkn| {
                    if (psr.lexer.token.ty == tkn) {
                        const op = psr.lexer.token;
                        _ = psr.lexer.next();

                        const right = try next(psr);
                        if (!right.isSuccess())
                            return right;

                        left = try makeNode(
                            psr.getAllocator(),
                            op.csr,
                            .BinaryOp,
                            node.BinaryOp.new(op.ty, left, right.Success),
                        );

                        continue :opLoop;
                    }
                }

                return ParseResult.success(left);
            }
        }
    };
}

const mulOpParser = BinaryOpParser(
    parsePrefixExpr,
    &[_]TokenType{ .Mul, .Div, .Mod },
);

const addOpParser = BinaryOpParser(
    mulOpParser.parse,
    &[_]TokenType{ .Add, .Sub },
);

const shiftOpParser = BinaryOpParser(
    addOpParser.parse,
    &[_]TokenType{ .ShiftLeft, .ShiftRight, .ShiftRightUnsigned },
);

const relationalOpParser = BinaryOpParser(
    shiftOpParser.parse,
    &[_]TokenType{
        .CmpGreater,
        .CmpLess,
        .CmpGreaterEq,
        .CmpLessEq,
        .InstanceOf,
        .In,
    },
);

const equalityOpParser = BinaryOpParser(
    relationalOpParser.parse,
    &[_]TokenType{ .CmpEq, .CmpNotEq, .CmpStrictEq, .CmpStrictNotEq },
);

const bitAndOpParser = BinaryOpParser(
    equalityOpParser.parse,
    &[_]TokenType{.BitAnd},
);

const bitXorOpParser = BinaryOpParser(
    bitAndOpParser.parse,
    &[_]TokenType{.BitXor},
);

const bitOrOpParser = BinaryOpParser(
    bitXorOpParser.parse,
    &[_]TokenType{.BitOr},
);

const logAndOpParser = BinaryOpParser(
    bitOrOpParser.parse,
    &[_]TokenType{.LogicalAnd},
);

const logOrOpParser = BinaryOpParser(
    logAndOpParser.parse,
    &[_]TokenType{.LogicalOr},
);

fn parseTernaryExpr(psr: *Parser) Parser.Error!ParseResult {
    const left = try logOrOpParser.parse(psr);
    if (!left.isSuccess())
        return left;

    if (psr.lexer.token.ty != .Question)
        return left;

    const csr = psr.lexer.token.csr;

    _ = psr.lexer.next();

    const ifTrue = try assignOpParser.parse(psr);
    if (!ifTrue.isSuccess())
        return ifTrue;

    if (psr.lexer.token.ty != .Colon)
        return ParseResult.expected(TokenType.Colon, psr.lexer.token);

    _ = psr.lexer.next();

    const ifFalse = try assignOpParser.parse(psr);
    if (!ifFalse.isSuccess())
        return ifFalse;

    return ParseResult.success(try makeNode(
        psr.getAllocator(),
        csr,
        .Ternary,
        node.Ternary.new(left.Success, ifTrue.Success, ifFalse.Success),
    ));
}

const assignOpParser = BinaryOpParser(
    parseTernaryExpr,
    &[_]TokenType{
        .Assign,
        .AddAssign,
        .SubAssign,
        .MulAssign,
        .DivAssign,
        .ModAssign,
        .ShiftLeftAssign,
        .ShiftRightAssign,
        .ShiftRightUnsignedAssign,
        .BitAndAssign,
        .BitOrAssign,
        .BitXorAssign,
    },
);

fn parseBinaryExpr(psr: *Parser) Parser.Error!ParseResult {
    return assignOpParser.parse(psr);
}

fn BinaryOpTestCase(op: []const u8, ty: TokenType) type {
    return struct {
        pub fn run() !void {
            try (ExprTestCase{
                .expr = "a " ++ op ++ " b",
                .startingCh = 2,
                .check = @This().check,
            }).run();
        }

        fn check(value: Node) anyerror!void {
            try expectEqual(NodeType.BinaryOp, value.getType());
            const data = value.data.BinaryOp;
            try expectEqual(ty, data.op);
            try expectEqual(NodeType.Ident, data.left.getType());
            try expectEqualStrings("a", data.left.data.Ident);
            try expectEqual(NodeType.Ident, data.right.getType());
            try expectEqualStrings("b", data.right.data.Ident);
        }
    };
}

test "can parse mul binary expressions" {
    try BinaryOpTestCase("*", .Mul).run();
    try BinaryOpTestCase("/", .Div).run();
    try BinaryOpTestCase("%", .Mod).run();
}

test "can parse add binary expressions" {
    try BinaryOpTestCase("+", .Add).run();
    try BinaryOpTestCase("-", .Sub).run();
}

test "can parse shift binary expressions" {
    try BinaryOpTestCase("<<", .ShiftLeft).run();
    try BinaryOpTestCase(">>", .ShiftRight).run();
    try BinaryOpTestCase(">>>", .ShiftRightUnsigned).run();
}

test "can parse relational binary expressions" {
    try BinaryOpTestCase(">", .CmpGreater).run();
    try BinaryOpTestCase("<", .CmpLess).run();
    try BinaryOpTestCase(">=", .CmpGreaterEq).run();
    try BinaryOpTestCase("<=", .CmpLessEq).run();
    try BinaryOpTestCase("instanceof", .InstanceOf).run();
    try BinaryOpTestCase("in", .In).run();
}

test "can parse equality binary expressions" {
    try BinaryOpTestCase("==", .CmpEq).run();
    try BinaryOpTestCase("!=", .CmpNotEq).run();
    try BinaryOpTestCase("===", .CmpStrictEq).run();
    try BinaryOpTestCase("!==", .CmpStrictNotEq).run();
}

test "can parse bitwise binary expressions" {
    try BinaryOpTestCase("&", .BitAnd).run();
    try BinaryOpTestCase("^", .BitXor).run();
    try BinaryOpTestCase("|", .BitOr).run();
}

test "can parse logical binary expressions" {
    try BinaryOpTestCase("&&", .LogicalAnd).run();
    try BinaryOpTestCase("||", .LogicalOr).run();
}

test "can parse assignment binary expressions" {
    try BinaryOpTestCase("=", .Assign).run();
    try BinaryOpTestCase("+=", .AddAssign).run();
    try BinaryOpTestCase("-=", .SubAssign).run();
    try BinaryOpTestCase("*=", .MulAssign).run();
    try BinaryOpTestCase("/=", .DivAssign).run();
    try BinaryOpTestCase("%=", .ModAssign).run();
    try BinaryOpTestCase("<<=", .ShiftLeftAssign).run();
    try BinaryOpTestCase(">>=", .ShiftRightAssign).run();
    try BinaryOpTestCase(">>>=", .ShiftRightUnsignedAssign).run();
    try BinaryOpTestCase("&=", .BitAndAssign).run();
    try BinaryOpTestCase("|=", .BitOrAssign).run();
    try BinaryOpTestCase("^=", .BitXorAssign).run();
}

test "can parse ternary expressions" {
    try (ExprTestCase{
        .expr = "a ? 1 : 'abc'",
        .startingCh = 2,
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Ternary, value.getType());
                const ternary = value.data.Ternary;
                try expectEqual(NodeType.Ident, ternary.cond.getType());
                try expectEqualStrings("a", ternary.cond.data.Ident);
                try expectEqual(NodeType.Int, ternary.ifTrue.getType());
                try expectEqualStrings("1", ternary.ifTrue.data.Int);
                try expectEqual(NodeType.String, ternary.ifFalse.getType());
                try expectEqualStrings("'abc'", ternary.ifFalse.data.String);
            }
        }).check,
    }).run();
}

pub fn parseExpr(psr: *Parser) Parser.Error!ParseResult {
    return parseBinaryExpr(psr);
}
