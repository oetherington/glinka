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
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Decl = node.Decl;
const TokenType = @import("../common/token.zig").Token.Type;
const parseresult = @import("parse_result.zig");
const ParseResult = parseresult.ParseResult;
const ParseError = @import("../common/parse_error.zig").ParseError;

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

        const eof = try parser.next();
        try expect(eof.isSuccess());
        try expectEqual(NodeType.EOF, eof.Success.getType());
    }
};

fn parseParenExpr(psr: *Parser) Parser.Error!ParseResult {
    std.debug.assert(psr.lexer.token.ty == .LParen);

    _ = psr.lexer.next();

    const expr = try psr.parseExpr();
    if (!expr.isSuccess())
        return expr;

    if (psr.lexer.token.ty != .RParen)
        return ParseResult.expected(TokenType.RParen, psr.lexer.token);

    _ = psr.lexer.next();

    return expr;
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

fn parseArrayLiteral(psr: *Parser) Parser.Error!ParseResult {
    std.debug.assert(psr.lexer.token.ty == .LBrack);

    const nd = try makeNode(
        psr.getAllocator(),
        psr.lexer.token.csr,
        .Array,
        node.NodeList{},
    );

    _ = psr.lexer.next();

    while (psr.lexer.token.ty != .RBrack) {
        const item = try parseBinaryExpr(psr);
        if (!item.isSuccess())
            return item;

        try nd.data.Array.append(psr.getAllocator(), item.Success);

        if (psr.lexer.token.ty != .Comma)
            break;

        _ = psr.lexer.next();
    }

    if (psr.lexer.token.ty != .RBrack)
        return ParseResult.expected(TokenType.RBrack, psr.lexer.token);

    _ = psr.lexer.next();

    return ParseResult.success(nd);
}

test "can parse array literal primary expression" {
    try (ExprTestCase{
        .expr = "[ 123, 'abc', true ]",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Array, value.getType());
                const items = value.data.Array.items;
                try expectEqual(@intCast(usize, 3), items.len);
                try expectEqual(NodeType.Int, items[0].getType());
                try expectEqualStrings("123", items[0].data.Int);
                try expectEqual(NodeType.String, items[1].getType());
                try expectEqualStrings("'abc'", items[1].data.String);
                try expectEqual(NodeType.True, items[2].getType());
            }
        }).check,
    }).run();
}

fn parsePropertyKey(psr: *Parser) Parser.Error!ParseResult {
    const alloc = psr.getAllocator();
    const csr = psr.lexer.token.csr;
    const data = psr.lexer.token.data;

    const nd = switch (psr.lexer.token.ty) {
        .Ident => try makeNode(alloc, csr, .Ident, data),
        .String => try makeNode(alloc, csr, .String, data),
        .Int => try makeNode(alloc, csr, .Int, data),
        else => return ParseResult.expected("property key", psr.lexer.token),
    };

    _ = psr.lexer.next();

    return ParseResult.success(nd);
}

fn parseObjectLiteral(psr: *Parser) Parser.Error!ParseResult {
    std.debug.assert(psr.lexer.token.ty == .LBrace);

    const nd = try makeNode(
        psr.getAllocator(),
        psr.lexer.token.csr,
        .Object,
        node.Object{},
    );

    _ = psr.lexer.next();

    while (psr.lexer.token.ty != .RBrace) {
        const key = try parsePropertyKey(psr);
        if (!key.isSuccess())
            return key;

        if (psr.lexer.token.ty == .Colon) {
            _ = psr.lexer.next();

            const value = try parseBinaryExpr(psr);
            if (!value.isSuccess())
                return value;

            try nd.data.Object.append(
                psr.getAllocator(),
                node.ObjectProperty.new(key.Success, value.Success),
            );
        } else if (key.Success.getType() == .Ident) {
            try nd.data.Object.append(
                psr.getAllocator(),
                node.ObjectProperty.new(key.Success, key.Success),
            );
        } else {
            return ParseResult.expected("property value", psr.lexer.token);
        }

        if (psr.lexer.token.ty != .Comma)
            break;

        _ = psr.lexer.next();
    }

    if (psr.lexer.token.ty != .RBrace)
        return ParseResult.expected(TokenType.RBrace, psr.lexer.token);

    _ = psr.lexer.next();

    return ParseResult.success(nd);
}

test "can parse object literal primary expression" {
    try (ExprTestCase{
        .expr = "{ a: 'hello', 'b': true, c }",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Object, value.getType());
                const items = value.data.Object.items;
                try expectEqual(@intCast(usize, 3), items.len);
                try expectEqual(NodeType.Ident, items[0].key.getType());
                try expectEqualStrings("a", items[0].key.data.Ident);
                try expectEqual(NodeType.String, items[0].value.getType());
                try expectEqualStrings("'hello'", items[0].value.data.String);
                try expectEqual(NodeType.String, items[1].key.getType());
                try expectEqualStrings("'b'", items[1].key.data.String);
                try expectEqual(NodeType.True, items[1].value.getType());
                try expectEqual(NodeType.Ident, items[2].key.getType());
                try expectEqualStrings("c", items[2].key.data.Ident);
                try expectEqual(NodeType.Ident, items[2].value.getType());
                try expectEqualStrings("c", items[2].value.data.Ident);
            }
        }).check,
    }).run();
}

fn parseFunctionExpr(psr: *Parser) Parser.Error!ParseResult {
    std.debug.assert(psr.lexer.token.ty == .Function);

    const csr = psr.lexer.token.csr;

    _ = psr.lexer.next();

    var func: node.Function = undefined;
    func.isArrow = false;

    if (psr.lexer.token.ty == .Ident) {
        func.name = psr.lexer.token.data;
        _ = psr.lexer.next();
    } else {
        func.name = null;
    }

    if (psr.lexer.token.ty != .LParen)
        return ParseResult.expected("function argument list", psr.lexer.token);

    _ = psr.lexer.next();

    func.args = node.Function.ArgList{};

    while (psr.lexer.token.ty != .RParen) {
        const arg = psr.lexer.token;
        if (arg.ty != .Ident)
            return ParseResult.expected("a function argument", arg);

        _ = psr.lexer.next();

        var ty: ?Node = null;

        if (psr.lexer.token.ty == .Colon) {
            _ = psr.lexer.next();

            const tyRes = try psr.parseType();
            if (!tyRes.isSuccess())
                return tyRes;

            ty = tyRes.Success;
        }

        try func.args.append(psr.getAllocator(), node.Function.Arg{
            .csr = arg.csr,
            .name = arg.data,
            .ty = ty,
        });

        if (psr.lexer.token.ty != .Comma)
            break;

        _ = psr.lexer.next();
    }

    if (psr.lexer.token.ty != .RParen)
        return ParseResult.expected(TokenType.RParen, psr.lexer.token);

    _ = psr.lexer.next();

    if (psr.lexer.token.ty == .Colon) {
        _ = psr.lexer.next();

        const retTy = try psr.parseType();
        if (!retTy.isSuccess())
            return retTy;

        func.retTy = retTy.Success;
    } else {
        func.retTy = null;
    }

    const body = try psr.parseBlock();
    if (!body.isSuccess())
        return body;

    func.body = body.Success;

    return ParseResult.success(try makeNode(
        psr.getAllocator(),
        csr,
        .Function,
        func,
    ));
}

test "can parse function definition" {
    try (ExprTestCase{
        .expr = "function hello(world: number, foo: string, bar) : bool {}",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Function, value.getType());

                const func = value.data.Function;
                try expectEqual(false, func.isArrow);
                try expectEqualStrings("hello", func.name.?);

                const retTy = func.retTy.?;
                try expectEqual(NodeType.TypeName, retTy.getType());
                try expectEqualStrings("bool", retTy.data.TypeName);

                const args = func.args.items;
                try expectEqual(@intCast(usize, 3), args.len);
                try expectEqualStrings("world", args[0].name);
                try expectEqual(NodeType.TypeName, args[0].ty.?.getType());
                try expectEqualStrings("number", args[0].ty.?.data.TypeName);
                try expectEqualStrings("foo", args[1].name);
                try expectEqual(NodeType.TypeName, args[1].ty.?.getType());
                try expectEqualStrings("string", args[1].ty.?.data.TypeName);
                try expectEqualStrings("bar", args[2].name);
                try expect(args[2].ty == null);

                const body = func.body;
                try expectEqual(NodeType.Block, body.getType());
                try expectEqual(@intCast(usize, 0), body.data.Block.items.len);
            }
        }).check,
    }).run();
}

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
        .LParen => return parseParenExpr(psr),
        .LBrack => return parseArrayLiteral(psr),
        .LBrace => return parseObjectLiteral(psr),
        .Function => return parseFunctionExpr(psr),
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

fn parseMemberExpr(psr: *Parser) Parser.Error!ParseResult {
    const left = try parsePrimaryExpr(psr);
    if (!left.isSuccess())
        return left;

    var nd = left.Success;

    while (true) {
        switch (psr.lexer.token.ty) {
            .Dot => {
                const csr = psr.lexer.token.csr;

                const ident = psr.lexer.next();
                if (ident.ty != .Ident)
                    return ParseResult.expected(
                        "identifier after '.'",
                        psr.lexer.token,
                    );

                _ = psr.lexer.next();

                nd = try makeNode(
                    psr.getAllocator(),
                    csr,
                    .Dot,
                    node.Dot{
                        .expr = nd,
                        .ident = ident.data,
                    },
                );
            },
            .LBrack => {
                const csr = psr.lexer.token.csr;

                _ = psr.lexer.next();

                const expr = try psr.parseExpr();
                if (!expr.isSuccess())
                    return expr;

                if (psr.lexer.token.ty != .RBrack)
                    return ParseResult.expected(
                        "']' after array access",
                        psr.lexer.token,
                    );

                _ = psr.lexer.next();

                nd = try makeNode(
                    psr.getAllocator(),
                    csr,
                    .ArrayAccess,
                    node.ArrayAccess{
                        .expr = nd,
                        .index = expr.Success,
                    },
                );
            },
            .LParen => {
                nd = try makeNode(
                    psr.getAllocator(),
                    psr.lexer.token.csr,
                    .Call,
                    node.Call{
                        .expr = nd,
                        .args = node.NodeList{},
                    },
                );

                _ = psr.lexer.next();

                while (psr.lexer.token.ty != .RParen) {
                    const expr = try parseBinaryExpr(psr);
                    switch (expr) {
                        .Success => |arg| try nd.data.Call.args.append(
                            psr.getAllocator(),
                            arg,
                        ),
                        .Error => return expr,
                        .NoMatch => return ParseResult.expected(
                            "an expression for function call",
                            psr.lexer.token,
                        ),
                    }

                    if (psr.lexer.token.ty == .Comma) {
                        _ = psr.lexer.next();
                    } else {
                        break;
                    }
                }

                if (psr.lexer.token.ty != .RParen)
                    return ParseResult.expected(
                        "')' after function call arguments",
                        psr.lexer.token,
                    );

                _ = psr.lexer.next();
            },
            else => break,
        }
    }

    return ParseResult.success(nd);
}

test "can parse dot expression" {
    try (ExprTestCase{
        .expr = "a.b.c",
        .startingCh = 3,
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Dot, value.getType());

                const second = value.data.Dot;
                try expectEqualStrings("c", second.ident);
                try expectEqual(NodeType.Dot, second.expr.getType());

                const first = second.expr.data.Dot;
                try expectEqualStrings("b", first.ident);
                try expectEqual(NodeType.Ident, first.expr.getType());
                try expectEqualStrings("a", first.expr.data.Ident);
            }
        }).check,
    }).run();
}

test "can parse array access expression" {
    try (ExprTestCase{
        .expr = "a[b][c]",
        .startingCh = 4,
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.ArrayAccess, value.getType());

                const second = value.data.ArrayAccess;
                try expectEqual(NodeType.Ident, second.index.getType());
                try expectEqualStrings("c", second.index.data.Ident);
                try expectEqual(NodeType.ArrayAccess, second.expr.getType());

                const first = second.expr.data.ArrayAccess;
                try expectEqual(NodeType.Ident, first.index.getType());
                try expectEqualStrings("b", first.index.data.Ident);
                try expectEqual(NodeType.Ident, first.expr.getType());

                try expectEqualStrings("a", first.expr.data.Ident);
            }
        }).check,
    }).run();
}

test "can parse function call without arguments" {
    try (ExprTestCase{
        .expr = "a()",
        .startingCh = 1,
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Call, value.getType());

                const call = value.data.Call;
                try expectEqual(NodeType.Ident, call.expr.getType());
                try expectEqualStrings("a", call.expr.data.Ident);
                try expectEqual(@intCast(usize, 0), call.args.items.len);
            }
        }).check,
    }).run();
}

test "can parse function call with arguments" {
    try (ExprTestCase{
        .expr = "a(b, true, 4)",
        .startingCh = 1,
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Call, value.getType());

                const call = value.data.Call;
                try expectEqual(NodeType.Ident, call.expr.getType());
                try expectEqualStrings("a", call.expr.data.Ident);

                const args = call.args.items;
                try expectEqual(@intCast(usize, 3), args.len);

                try expectEqual(NodeType.Ident, args[0].getType());
                try expectEqualStrings("b", args[0].data.Ident);

                try expectEqual(NodeType.True, args[1].getType());

                try expectEqual(NodeType.Int, args[2].getType());
                try expectEqualStrings("4", args[2].data.Int);
            }
        }).check,
    }).run();
}

fn parsePostfixExpr(psr: *Parser) Parser.Error!ParseResult {
    const res = try parseMemberExpr(psr);
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

fn parseCommaExpr(psr: *Parser) Parser.Error!ParseResult {
    const res = try parseBinaryExpr(psr);
    if (!res.isSuccess() or psr.lexer.token.ty != .Comma)
        return res;

    const alloc = psr.getAllocator();

    var list = try makeNode(
        alloc,
        psr.lexer.token.csr,
        .Comma,
        node.NodeList{},
    );

    try list.data.Comma.append(alloc, res.Success);

    while (psr.lexer.token.ty == .Comma) {
        _ = psr.lexer.next();

        const right = try parseBinaryExpr(psr);
        if (!right.isSuccess())
            return right;

        try list.data.Comma.append(alloc, right.Success);
    }

    return ParseResult.success(list);
}

test "can parse comma expressions" {
    try (ExprTestCase{
        .expr = "a, 1, 'abc'",
        .startingCh = 1,
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Comma, value.getType());
                const items = value.data.Comma.items;
                try expectEqual(@intCast(usize, 3), items.len);
                try expectEqual(NodeType.Ident, items[0].getType());
                try expectEqualStrings("a", items[0].data.Ident);
                try expectEqual(NodeType.Int, items[1].getType());
                try expectEqualStrings("1", items[1].data.Int);
                try expectEqual(NodeType.String, items[2].getType());
                try expectEqualStrings("'abc'", items[2].data.String);
            }
        }).check,
    }).run();
}

pub fn parseExpr(psr: *Parser) Parser.Error!ParseResult {
    return parseCommaExpr(psr);
}
