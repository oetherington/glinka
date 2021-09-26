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
const Cursor = @import("cursor.zig").Cursor;
const Token = @import("token.zig").Token;
const node = @import("node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Decl = node.Decl;
const ParseError = @import("parse_error.zig").ParseError;

pub const ParseResultType = enum {
    Success,
    Error,
    NoMatch,
};

pub const ParseResult = union(ParseResultType) {
    Success: Node,
    Error: ParseError,
    NoMatch: ?ParseError,

    pub fn success(n: Node) ParseResult {
        return ParseResult{
            .Success = n,
        };
    }

    pub fn err(e: ParseError) ParseResult {
        return ParseResult{
            .Error = e,
        };
    }

    pub fn errMessage(csr: Cursor, message: []const u8) ParseResult {
        return ParseResult.err(ParseError.message(csr, message));
    }

    pub fn expected(expectedData: anytype, foundData: anytype) ParseResult {
        return ParseResult.err(ParseError.expected(expectedData, foundData));
    }

    pub fn noMatch(e: ?ParseError) ParseResult {
        return ParseResult{
            .NoMatch = e,
        };
    }

    pub fn noMatchExpected(
        expectedData: anytype,
        foundData: anytype,
    ) ParseResult {
        return ParseResult.noMatch(ParseError.expected(
            expectedData,
            foundData,
        ));
    }

    pub fn getType(self: ParseResult) ParseResultType {
        return @as(ParseResultType, self);
    }

    pub fn isSuccess(self: ParseResult) bool {
        return @as(ParseResultType, self) == .Success;
    }

    pub fn reportIfError(self: ParseResult, writer: anytype) !void {
        switch (self) {
            .Success => {},
            .Error => |err| try err.report(writer),
            .NoMatch => |err| if (err) |e| try e.report(writer),
        }
    }
};

test "can initialize 'Success' parse result" {
    const n = makeNode(
        std.testing.allocator,
        Cursor.new(0, 0),
        NodeType.Decl,
        Decl.new(.Var, "aName", null, null),
    );
    defer std.testing.allocator.destroy(n);
    const res = ParseResult.success(n);
    try expectEqual(ParseResultType.Success, res.getType());
    try expectEqual(n, res.Success);
    try expect(res.isSuccess());
}

test "can initialize 'Error' parse result" {
    const expected = Token.Type.Dot;
    const found = makeNode(
        std.testing.allocator,
        Cursor.new(0, 0),
        NodeType.Decl,
        Decl.new(.Var, "aName", null, null),
    );
    defer std.testing.allocator.destroy(found);
    const err = ParseError.expected(expected, found);
    const res = ParseResult.err(err);
    try expectEqual(ParseResultType.Error, res.getType());
    try expectEqual(err, res.Error);
    try expect(!res.isSuccess());
}

test "can initialize 'NoMatch' parse result without a payload" {
    const res = ParseResult.noMatch(null);
    try expectEqual(ParseResultType.NoMatch, res.getType());
    try expect(res.NoMatch == null);
    try expect(!res.isSuccess());
}

test "can initialize 'NoMatch' parse result with a payload" {
    const expected = Token.Type.Dot;
    const found = makeNode(
        std.testing.allocator,
        Cursor.new(0, 0),
        NodeType.Decl,
        Decl.new(.Var, "aName", null, null),
    );
    defer std.testing.allocator.destroy(found);
    const err = ParseError.expected(expected, found);
    const res = ParseResult.noMatch(err);
    try expectEqual(ParseResultType.NoMatch, res.getType());
    try expectEqual(err, res.NoMatch.?);
}
