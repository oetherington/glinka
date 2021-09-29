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
const Arena = std.heap.ArenaAllocator;
const TsParser = @import("ts_parser.zig").TsParser;
const Parser = @import("../common/parser.zig").Parser;
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Decl = node.Decl;
const TokenType = @import("../common/token.zig").TokenType;
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

pub fn parseTypeName(psr: *TsParser) ParseResult {
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

pub fn parseType(psr: *Parser) ParseResult {
    return parseTypeName(@fieldParentPtr(TsParser, "parser", psr));
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
