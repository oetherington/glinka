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
const Cursor = @import("../common/cursor.zig").Cursor;
const token = @import("token.zig");
const TokenType = token.TokenType;
const Token = token.Token;
const node = @import("node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Decl = node.Decl;

pub const ExpectedDataType = enum {
    Token,
    String,
};

pub const ExpectedData = union(ExpectedDataType) {
    Token: TokenType,
    String: []const u8,

    pub fn new(data: anytype) ExpectedData {
        return switch (@typeInfo(@TypeOf(data))) {
            .Enum => ExpectedData{ .Token = data },
            .Pointer => ExpectedData{ .String = data },
            else => @compileError("expected must be a TokenType or a string"),
        };
    }

    pub fn getType(self: ExpectedData) ExpectedDataType {
        return @as(ExpectedDataType, self);
    }

    pub fn write(self: ExpectedData, writer: anytype) !void {
        switch (self) {
            .Token => |t| try writer.print("{s}", .{@tagName(t)}),
            .String => |s| try writer.print("{s}", .{s}),
        }
    }
};

test "can initialize 'ExpectedData' with a TokenType" {
    const tt = TokenType.Dot;
    const data = ExpectedData.new(tt);
    try expectEqual(ExpectedData.Token, data.getType());
    try expectEqual(tt, data.Token);
}

test "can initialize 'ExpectedData' with a string" {
    const str: []const u8 = "some expected thing";
    const data = ExpectedData.new(str);
    try expectEqual(ExpectedData.String, data.getType());
    try expectEqualSlices(u8, str, data.String);
}

pub const FoundDataType = enum {
    Token,
    Node,
};

pub const FoundData = union(FoundDataType) {
    Token: Token,
    Node: Node,

    pub fn new(data: anytype) FoundData {
        return switch (@typeInfo(@TypeOf(data))) {
            .Struct => FoundData{ .Token = data },
            .Pointer => FoundData{ .Node = data },
            else => @compileError("found must be a Token or a Node"),
        };
    }

    pub fn getCursor(self: FoundData) Cursor {
        return switch (self) {
            .Token => self.Token.csr,
            .Node => self.Node.csr,
        };
    }

    pub fn getType(self: FoundData) FoundDataType {
        return @as(FoundDataType, self);
    }

    pub fn write(self: FoundData, writer: anytype) !void {
        switch (self) {
            .Token => |t| try writer.print("{s}", .{@tagName(t.ty)}),
            .Node => |n| try writer.print("{s}", .{@tagName(n.getType())}),
        }
    }
};

test "can initialize 'FoundData' with a Token" {
    const tkn = Token.new(TokenType.Eq, Cursor.new(0, 0));
    const data = FoundData.new(tkn);
    try expectEqual(FoundData.Token, data.getType());
    try expectEqual(tkn, data.Token);
}

test "can initialize 'FoundData' with a Node" {
    const found = try makeNode(
        std.testing.allocator,
        Cursor.new(0, 0),
        NodeType.Var,
        Decl.new("aName", null, null),
    );
    defer std.testing.allocator.destroy(found);
    const data = FoundData.new(found);
    try expectEqual(FoundData.Node, data.getType());
    try expectEqual(found, data.Node);
}

pub const Expected = struct {
    expected: ExpectedData,
    found: FoundData,

    pub fn new(expectedData: anytype, foundData: anytype) Expected {
        return Expected{
            .expected = ExpectedData.new(expectedData),
            .found = FoundData.new(foundData),
        };
    }

    pub fn getCursor(self: Expected) Cursor {
        return self.found.getCursor();
    }

    pub fn write(self: Expected, writer: anytype) !void {
        try writer.print("Expected ", .{});
        try self.expected.write(writer);
        try writer.print(" but found ", .{});
        try self.found.write(writer);
    }
};

test "can initialize Expected" {
    const tokenType = TokenType.Dot;
    const foundTkn = Token.new(TokenType.Eq, Cursor.new(0, 0));
    const expected = Expected.new(tokenType, foundTkn);
    try expectEqual(ExpectedDataType.Token, expected.expected.getType());
    try expectEqual(FoundDataType.Token, expected.found.getType());
    try expectEqual(foundTkn.csr, expected.getCursor());
}

pub const ParseErrorType = enum {
    Expected,
    Message,
};

pub const ParseErrorData = union(ParseErrorType) {
    Expected: Expected,
    Message: []const u8,

    pub fn write(self: ParseErrorData, writer: anytype) !void {
        switch (self) {
            .Expected => |e| try e.write(writer),
            .Message => |m| try writer.print("{s}", .{m}),
        }
    }
};

pub const ParseError = struct {
    csr: Cursor,
    data: ParseErrorData,

    pub fn expected(expectedData: anytype, foundData: anytype) ParseError {
        const exp = Expected.new(expectedData, foundData);
        return ParseError{
            .csr = exp.getCursor(),
            .data = ParseErrorData{
                .Expected = exp,
            },
        };
    }

    pub fn message(csr: Cursor, msg: []const u8) ParseError {
        return ParseError{
            .csr = csr,
            .data = ParseErrorData{
                .Message = msg,
            },
        };
    }

    pub fn getType(self: ParseError) ParseErrorType {
        return @as(ParseErrorType, self.data);
    }

    pub fn report(self: ParseError, writer: anytype) !void {
        try writer.print("Parse Error: {d}:{d}: ", .{
            self.csr.ln,
            self.csr.ch,
        });

        try self.data.write(writer);

        try writer.print("\n", .{});
    }
};

test "can initialize a 'ParseError' with an expected type" {
    const tokenType = TokenType.Dot;
    const foundTkn = Token.new(TokenType.Eq, Cursor.new(0, 0));
    const err = ParseError.expected(tokenType, foundTkn);
    try expectEqual(ParseErrorType.Expected, err.getType());
    try expectEqual(foundTkn.csr, err.csr);
    try expectEqual(
        ExpectedDataType.Token,
        err.data.Expected.expected.getType(),
    );
    try expectEqual(
        FoundDataType.Token,
        err.data.Expected.found.getType(),
    );
}

test "can initialize a 'ParseError' with an error message string" {
    const csr = Cursor.new(2, 4);
    const message: []const u8 = "any error message";
    const err = ParseError.message(csr, message);
    try expectEqual(ParseErrorType.Message, err.getType());
    try expectEqual(csr, err.csr);
    try expectEqualSlices(u8, message, err.data.Message);
}

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

    pub fn getType(self: ParseResult) ParseResultType {
        return @as(ParseResultType, self);
    }

    pub fn isSuccess(self: ParseResult) bool {
        return @as(ParseResultType, self) == .Success;
    }
};

test "can initialize 'Success' parse result" {
    const n = try makeNode(
        std.testing.allocator,
        Cursor.new(0, 0),
        NodeType.Var,
        Decl.new("aName", null, null),
    );
    defer std.testing.allocator.destroy(n);
    const res = ParseResult.success(n);
    try expectEqual(ParseResultType.Success, res.getType());
    try expectEqual(n, res.Success);
    try expect(res.isSuccess());
}

test "can initialize 'Error' parse result" {
    const expected = TokenType.Dot;
    const found = try makeNode(
        std.testing.allocator,
        Cursor.new(0, 0),
        NodeType.Var,
        Decl.new("aName", null, null),
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
    const expected = TokenType.Dot;
    const found = try makeNode(
        std.testing.allocator,
        Cursor.new(0, 0),
        NodeType.Var,
        Decl.new("aName", null, null),
    );
    defer std.testing.allocator.destroy(found);
    const err = ParseError.expected(expected, found);
    const res = ParseResult.noMatch(err);
    try expectEqual(ParseResultType.NoMatch, res.getType());
    try expectEqual(err, res.NoMatch.?);
}
