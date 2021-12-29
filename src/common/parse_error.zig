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
const Cursor = @import("cursor.zig").Cursor;
const Token = @import("token.zig").Token;
const node = @import("node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Decl = node.Decl;

pub const ExpectedData = union(Type) {
    pub const Type = enum {
        Token,
        String,
    };

    Token: Token.Type,
    String: []const u8,

    pub fn new(data: anytype) ExpectedData {
        return switch (@typeInfo(@TypeOf(data))) {
            .Enum => ExpectedData{ .Token = data },
            .Pointer => ExpectedData{ .String = data },
            else => @compileError("expected must be a Token.Type or a string"),
        };
    }

    pub fn getType(self: ExpectedData) Type {
        return @as(Type, self);
    }

    pub fn write(self: ExpectedData, writer: anytype) !void {
        switch (self) {
            .Token => |t| try writer.print("{s}", .{@tagName(t)}),
            .String => |s| try writer.print("{s}", .{s}),
        }
    }
};

test "can initialize 'ExpectedData' with a Token.Type" {
    const tt = Token.Type.Dot;
    const data = ExpectedData.new(tt);
    try expectEqual(ExpectedData.Token, data.getType());
    try expectEqual(tt, data.Token);
}

test "can initialize 'ExpectedData' with a string" {
    const str: []const u8 = "some expected thing";
    const data = ExpectedData.new(str);
    try expectEqual(ExpectedData.String, data.getType());
    try expectEqualStrings(str, data.String);
}

pub const FoundData = union(Type) {
    pub const Type = enum {
        Token,
        Node,
    };

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

    pub fn getType(self: FoundData) Type {
        return @as(Type, self);
    }

    pub fn write(self: FoundData, writer: anytype) !void {
        switch (self) {
            .Token => |t| try writer.print("{s}", .{@tagName(t.ty)}),
            .Node => |n| try writer.print("{s}", .{@tagName(n.getType())}),
        }
    }
};

test "can initialize 'FoundData' with a Token" {
    const tkn = Token.new(Token.Type.Assign, Cursor.new(0, 0));
    const data = FoundData.new(tkn);
    try expectEqual(FoundData.Token, data.getType());
    try expectEqual(tkn, data.Token);
}

test "can initialize 'FoundData' with a Node" {
    const found = makeNode(
        std.testing.allocator,
        Cursor.new(0, 0),
        NodeType.Decl,
        Decl.new(.Var, "aName", null, null),
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
    const tokenType = Token.Type.Dot;
    const foundTkn = Token.new(Token.Type.Assign, Cursor.new(0, 0));
    const expected = Expected.new(tokenType, foundTkn);
    try expectEqual(ExpectedData.Type.Token, expected.expected.getType());
    try expectEqual(FoundData.Type.Token, expected.found.getType());
    try expectEqual(foundTkn.csr, expected.getCursor());
}

pub const ParseErrorData = union(Type) {
    pub const Type = enum {
        Expected,
        Message,
    };

    Expected: Expected,
    Message: []const u8,

    pub fn write(self: ParseErrorData, writer: anytype) !void {
        switch (self) {
            .Expected => |e| try e.write(writer),
            .Message => |m| try writer.print("{s}", .{m}),
        }
    }

    pub fn getType(self: ParseErrorData) Type {
        return @as(Type, self);
    }
};

pub const ParseError = struct {
    pub const Type = ParseErrorData.Type;

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

    pub fn getType(self: ParseError) ParseErrorData.Type {
        return self.data.getType();
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
    const tokenType = Token.Type.Dot;
    const foundTkn = Token.new(Token.Type.Assign, Cursor.new(0, 0));
    const err = ParseError.expected(tokenType, foundTkn);
    try expectEqual(ParseError.Type.Expected, err.getType());
    try expectEqual(foundTkn.csr, err.csr);
    try expectEqual(
        ExpectedData.Type.Token,
        err.data.Expected.expected.getType(),
    );
    try expectEqual(
        FoundData.Type.Token,
        err.data.Expected.found.getType(),
    );
}

test "can initialize a 'ParseError' with an error message string" {
    const csr = Cursor.new(2, 4);
    const message: []const u8 = "any error message";
    const err = ParseError.message(csr, message);
    try expectEqual(ParseError.Type.Message, err.getType());
    try expectEqual(csr, err.csr);
    try expectEqualStrings(message, err.data.Message);
}
