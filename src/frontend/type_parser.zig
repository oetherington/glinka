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

pub fn parseType(psr: *Parser) Parser.Error!ParseResult {
    switch (psr.lexer.token.ty) {
        .Ident => {
            const nd = try makeNode(
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
    const code = " SomeTypeName ";

    var parser = Parser.new(std.testing.allocator, code);
    defer parser.deinit();

    const res = try parser.parseType();
    try expect(res.isSuccess());
    try expectEqual(Cursor.new(1, 2), res.Success.csr);
    try expectEqual(NodeType.TypeName, res.Success.data.getType());
    try expectEqualSlices(u8, "SomeTypeName", res.Success.data.TypeName);
}
