// glinka
// Copyright (C) 2021-2022 Ollie Etherington
// <www.etherington.io>
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
const Arena = std.heap.ArenaAllocator;
const TsParser = @import("ts_parser.zig").TsParser;
const Parser = @import("../common/parser.zig").Parser;
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Decl = node.Decl;
const TokenType = @import("../common/token.zig").Token.Type;
const parseresult = @import("../common/parse_result.zig");
const ParseResult = parseresult.ParseResult;
const ParseError = @import("../common/parse_error.zig").ParseError;
const allocate = @import("../common/allocate.zig");

const ParseTypeTestCase = struct {
    code: []const u8,
    check: fn (res: ParseResult) anyerror!void,

    pub fn run(self: ParseTypeTestCase) !void {
        var arena = Arena.init(std.testing.allocator);
        defer arena.deinit();

        var tsParser = TsParser.new(&arena, self.code);

        var parser = tsParser.getParser();

        const res = parser.parseType();
        try self.check(res);
    }
};

pub fn parseInlineInterfaceType(psr: *TsParser) ParseResult {
    std.debug.assert(psr.lexer.token.ty == .LBrace);

    const alloc = psr.getAllocator();
    const csr = psr.lexer.token.csr;

    _ = psr.lexer.next();

    var res = node.InterfaceTypeMemberList{};

    while (true) {
        // TODO: Should strings be valid here as well as identifiers?
        if (psr.lexer.token.ty != .Ident)
            return ParseResult.expected(
                "name for interface member",
                psr.lexer.token,
            );

        const name = psr.lexer.token.data;

        if (psr.lexer.next().ty != .Colon)
            return ParseResult.expected(TokenType.Colon, psr.lexer.token);

        _ = psr.lexer.next();

        const ty = parseTypeInternal(psr);
        if (!ty.isSuccess())
            return ParseResult.expected(
                "type for interface member",
                psr.lexer.token,
            );

        res.append(
            alloc,
            node.InterfaceTypeMember.new(name, ty.Success),
        ) catch allocate.reportAndExit();

        switch (psr.lexer.token.ty) {
            .Comma, .Semi => {
                if (psr.lexer.next().ty == .RBrace) {
                    _ = psr.lexer.next();
                    break;
                } else {
                    continue;
                }
            },
            .RBrace => {
                _ = psr.lexer.next();
                break;
            },
            else => return ParseResult.expected(
                "comma or left brace",
                psr.lexer.token,
            ),
        }
    }

    return ParseResult.success(makeNode(
        alloc,
        csr,
        .InterfaceType,
        node.InterfaceType{
            .name = null,
            .members = res,
        },
    ));
}

test "can parse inline interface types" {
    try (ParseTypeTestCase{
        .code = " { a: number, b: string } ",
        .check = (struct {
            fn check(res: ParseResult) anyerror!void {
                try expect(res.isSuccess());
                try expectEqual(Cursor.new(1, 2), res.Success.csr);
                try expectEqual(
                    NodeType.InterfaceType,
                    res.Success.data.getType(),
                );

                try expect(res.Success.data.InterfaceType.name == null);

                const members = res.Success.data.InterfaceType.members.items;
                try expectEqual(@intCast(usize, 2), members.len);
                try expectEqualStrings("a", members[0].name);
                try expectEqual(NodeType.TypeName, members[0].ty.getType());
                try expectEqualStrings("number", members[0].ty.data.TypeName);
                try expectEqualStrings("b", members[1].name);
                try expectEqual(NodeType.TypeName, members[1].ty.getType());
                try expectEqualStrings("string", members[1].ty.data.TypeName);
            }
        }).check,
    }).run();
}

test "can parse inline interface types with semicolons and trailing comma" {
    try (ParseTypeTestCase{
        .code = " { a: number; b: string, } ",
        .check = (struct {
            fn check(res: ParseResult) anyerror!void {
                try expect(res.isSuccess());
                try expectEqual(Cursor.new(1, 2), res.Success.csr);
                try expectEqual(
                    NodeType.InterfaceType,
                    res.Success.data.getType(),
                );

                try expect(res.Success.data.InterfaceType.name == null);

                const members = res.Success.data.InterfaceType.members.items;
                try expectEqual(@intCast(usize, 2), members.len);
                try expectEqualStrings("a", members[0].name);
                try expectEqual(NodeType.TypeName, members[0].ty.getType());
                try expectEqualStrings("number", members[0].ty.data.TypeName);
                try expectEqualStrings("b", members[1].name);
                try expectEqual(NodeType.TypeName, members[1].ty.getType());
                try expectEqualStrings("string", members[1].ty.data.TypeName);
            }
        }).check,
    }).run();
}

fn parseTypeName(psr: *TsParser) ParseResult {
    switch (psr.lexer.token.ty) {
        .Ident => {
            const nd = makeNode(
                psr.getAllocator(),
                psr.lexer.token.csr,
                NodeType.TypeName,
                psr.lexer.token.data,
            );

            _ = psr.lexer.next();

            return ParseResult.success(nd);
        },
        .Void => {
            const nd = makeNode(
                psr.getAllocator(),
                psr.lexer.token.csr,
                NodeType.TypeName,
                "void",
            );

            _ = psr.lexer.next();

            return ParseResult.success(nd);
        },
        .Null => {
            const nd = makeNode(
                psr.getAllocator(),
                psr.lexer.token.csr,
                NodeType.TypeName,
                "null",
            );

            _ = psr.lexer.next();

            return ParseResult.success(nd);
        },
        .Undefined => {
            const nd = makeNode(
                psr.getAllocator(),
                psr.lexer.token.csr,
                NodeType.TypeName,
                "undefined",
            );

            _ = psr.lexer.next();

            return ParseResult.success(nd);
        },
        .LParen => {
            _ = psr.lexer.next();
            const res = parseTypeInternal(psr);
            if (!res.isSuccess())
                return res;
            if (psr.lexer.token.ty != .RParen)
                return ParseResult.expected(TokenType.RParen, psr.lexer.token);
            _ = psr.lexer.next();
            return res;
        },
        .LBrace => return parseInlineInterfaceType(psr),
        else => return ParseResult.noMatch(null),
    }
}

test "can parse type names" {
    try (ParseTypeTestCase{
        .code = " ATypeName ",
        .check = (struct {
            fn check(res: ParseResult) anyerror!void {
                try expect(res.isSuccess());
                try expectEqual(Cursor.new(1, 2), res.Success.csr);
                try expectEqual(NodeType.TypeName, res.Success.data.getType());
                try expectEqualStrings("ATypeName", res.Success.data.TypeName);
            }
        }).check,
    }).run();
}

test "can parse void type" {
    try (ParseTypeTestCase{
        .code = " void ",
        .check = (struct {
            fn check(res: ParseResult) anyerror!void {
                try expect(res.isSuccess());
                try expectEqual(Cursor.new(1, 2), res.Success.csr);
                try expectEqual(NodeType.TypeName, res.Success.data.getType());
                try expectEqualStrings("void", res.Success.data.TypeName);
            }
        }).check,
    }).run();
}

test "can parse null type" {
    try (ParseTypeTestCase{
        .code = " null ",
        .check = (struct {
            fn check(res: ParseResult) anyerror!void {
                try expect(res.isSuccess());
                try expectEqual(Cursor.new(1, 2), res.Success.csr);
                try expectEqual(NodeType.TypeName, res.Success.data.getType());
                try expectEqualStrings("null", res.Success.data.TypeName);
            }
        }).check,
    }).run();
}

test "can parse undefined type" {
    try (ParseTypeTestCase{
        .code = " undefined ",
        .check = (struct {
            fn check(res: ParseResult) anyerror!void {
                try expect(res.isSuccess());
                try expectEqual(Cursor.new(1, 2), res.Success.csr);
                try expectEqual(NodeType.TypeName, res.Success.data.getType());
                try expectEqualStrings("undefined", res.Success.data.TypeName);
            }
        }).check,
    }).run();
}

fn parseArrayType(psr: *TsParser) ParseResult {
    var res = parseTypeName(psr);
    if (!res.isSuccess())
        return res;

    while (psr.lexer.token.ty == .LBrack) {
        const next = psr.lexer.next();
        if (next.ty != .RBrack)
            return ParseResult.expected(TokenType.RBrack, next);

        _ = psr.lexer.next();

        res = ParseResult.success(makeNode(
            psr.getAllocator(),
            res.Success.csr,
            NodeType.ArrayType,
            res.Success,
        ));
    }

    return res;
}

test "can parse array type" {
    try (ParseTypeTestCase{
        .code = " number[] ",
        .check = (struct {
            fn check(res: ParseResult) anyerror!void {
                try expect(res.isSuccess());
                try expectEqual(Cursor.new(1, 2), res.Success.csr);
                try expectEqual(NodeType.ArrayType, res.Success.getType());

                const subtype = res.Success.data.ArrayType;
                try expectEqual(NodeType.TypeName, subtype.getType());
                try expectEqualStrings("number", subtype.data.TypeName);
            }
        }).check,
    }).run();
}

test "can parse multidimensional array type" {
    try (ParseTypeTestCase{
        .code = " string[][] ",
        .check = (struct {
            fn check(res: ParseResult) anyerror!void {
                try expect(res.isSuccess());
                try expectEqual(Cursor.new(1, 2), res.Success.csr);
                try expectEqual(NodeType.ArrayType, res.Success.getType());

                const subtype1 = res.Success.data.ArrayType;
                try expectEqual(NodeType.ArrayType, subtype1.getType());

                const subtype2 = subtype1.data.ArrayType;
                try expectEqual(NodeType.TypeName, subtype2.getType());
                try expectEqualStrings("string", subtype2.data.TypeName);
            }
        }).check,
    }).run();
}

fn parseUnionType(psr: *TsParser) ParseResult {
    const res = parseArrayType(psr);
    if (!res.isSuccess() or psr.lexer.token.ty != .BitOr)
        return res;

    const alloc = psr.getAllocator();

    const un = makeNode(
        alloc,
        psr.lexer.token.csr,
        NodeType.UnionType,
        node.NodeList{},
    );

    un.data.UnionType.append(
        alloc,
        res.Success,
    ) catch allocate.reportAndExit();

    while (psr.lexer.token.ty == .BitOr) {
        _ = psr.lexer.next();

        const right = parseArrayType(psr);
        if (!right.isSuccess())
            return right;

        un.data.UnionType.append(
            alloc,
            right.Success,
        ) catch allocate.reportAndExit();
    }

    return ParseResult.success(un);
}

test "can parse union types" {
    try (ParseTypeTestCase{
        .code = " number | string | boolean ",
        .check = (struct {
            fn check(res: ParseResult) anyerror!void {
                try expect(res.isSuccess());

                const un = res.Success;
                try expectEqual(NodeType.UnionType, un.getType());

                const tys = un.data.UnionType.items;
                try expectEqual(@intCast(usize, 3), tys.len);
                try expectEqual(NodeType.TypeName, tys[0].getType());
                try expectEqualStrings("number", tys[0].data.TypeName);
                try expectEqual(NodeType.TypeName, tys[1].getType());
                try expectEqualStrings("string", tys[1].data.TypeName);
                try expectEqual(NodeType.TypeName, tys[2].getType());
                try expectEqualStrings("boolean", tys[2].data.TypeName);
            }
        }).check,
    }).run();
}

fn parseTypeInternal(psr: *TsParser) ParseResult {
    return parseUnionType(psr);
}

pub fn parseType(psr: *Parser) ParseResult {
    return parseTypeInternal(@fieldParentPtr(TsParser, "parser", psr));
}

test "can parse nested types" {
    try (ParseTypeTestCase{
        .code = " (number|string)[] ",
        .check = (struct {
            fn check(res: ParseResult) anyerror!void {
                try expect(res.isSuccess());

                const ty = res.Success;
                try expectEqual(NodeType.ArrayType, ty.getType());

                const sub = ty.data.ArrayType;
                try expectEqual(NodeType.UnionType, sub.getType());

                const tys = sub.data.UnionType.items;
                try expectEqual(@intCast(usize, 2), tys.len);
                try expectEqual(NodeType.TypeName, tys[0].getType());
                try expectEqualStrings("number", tys[0].data.TypeName);
                try expectEqual(NodeType.TypeName, tys[1].getType());
                try expectEqualStrings("string", tys[1].data.TypeName);
            }
        }).check,
    }).run();
}

test "invalid types return NoMatch" {
    try (ParseTypeTestCase{
        .code = " 3 ",
        .check = (struct {
            fn check(res: ParseResult) anyerror!void {
                try expectEqual(ParseResult.Type.NoMatch, res.getType());
            }
        }).check,
    }).run();
}
