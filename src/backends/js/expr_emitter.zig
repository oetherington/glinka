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
const expectEqualStrings = std.testing.expectEqualStrings;
const node = @import("../../frontend/node.zig");
const Node = node.Node;
const Cursor = @import("../../common/cursor.zig").Cursor;
const Backend = @import("../backend.zig").Backend;
const JsBackend = @import("js_backend.zig").JsBackend;

pub fn emitExpr(self: JsBackend, value: Node) Backend.Error!void {
    try switch (value.data) {
        .Ident => |i| self.out.print("{s}", .{i}),
        .Int => |i| self.out.print("{s}", .{i}),
        .String => |s| self.out.print("{s}", .{s}),
        .Template => |t| self.out.print("{s}", .{t}),
        .True => self.out.print("true", .{}),
        .False => self.out.print("false", .{}),
        .Null => self.out.print("null", .{}),
        .Undefined => self.out.print("undefined", .{}),
        else => std.debug.panic(
            "Invalid Node type in emitExpr: {?}",
            .{value},
        ),
    };
}

const ExprTestCase = struct {
    inputNode: Node,
    expectedOutput: []const u8,

    pub fn run(self: ExprTestCase) !void {
        var backend = try JsBackend.new(std.testing.allocator);
        defer backend.deinit();

        try emitExpr(backend, self.inputNode);

        const str = try backend.toString();
        defer backend.freeString(str);
        try expectEqualStrings(self.expectedOutput, str);

        std.testing.allocator.destroy(self.inputNode);
    }

    pub fn makeNode(comptime ty: node.NodeType, data: anytype) !Node {
        return try node.makeNode(
            std.testing.allocator,
            Cursor.new(0, 0),
            ty,
            data,
        );
    }
};

test "JsBackend can emit ident expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(.Ident, "anIdentifier"),
        .expectedOutput = "anIdentifier",
    }).run();
}

test "JsBackend can emit int expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(.Int, "123"),
        .expectedOutput = "123",
    }).run();
}

test "JsBackend can emit string expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(.String, "'a test string'"),
        .expectedOutput = "'a test string'",
    }).run();
}

test "JsBackend can emit template expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(.Template, "`a test template`"),
        .expectedOutput = "`a test template`",
    }).run();
}

test "JsBackend can emit 'true' expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(.True, {}),
        .expectedOutput = "true",
    }).run();
}

test "JsBackend can emit 'false' expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(.False, {}),
        .expectedOutput = "false",
    }).run();
}

test "JsBackend can emit 'null' expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(.Null, {}),
        .expectedOutput = "null",
    }).run();
}

test "JsBackend can emit 'undefined' expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(.Undefined, {}),
        .expectedOutput = "undefined",
    }).run();
}
