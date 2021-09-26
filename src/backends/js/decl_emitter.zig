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
const node = @import("../../common/node.zig");
const Node = node.Node;
const Cursor = @import("../../common/cursor.zig").Cursor;
const Backend = @import("../../common/backend.zig").Backend;
const JsBackend = @import("js_backend.zig").JsBackend;

pub fn emitDecl(self: *JsBackend, decl: node.Decl) Backend.Error!void {
    try self.out.print("{s} {s}", .{ decl.scoping.toString(), decl.name });

    if (decl.value) |value| {
        try self.out.print(" = ", .{});
        try self.emitExpr(value);
    }

    try self.out.print(";\n", .{});
}

const DeclTestCase = struct {
    inputTy: []const u8,
    scoping: node.Decl.Scoping,
    expectedOutput: []const u8,

    pub fn run(self: DeclTestCase) !void {
        var value = try DeclTestCase.makeNode(.Null, {});
        defer std.testing.allocator.destroy(value);

        var decl = try DeclTestCase.makeNode(
            .Decl,
            node.Decl.new(self.scoping, "test", null, value),
        );
        defer std.testing.allocator.destroy(decl);

        var backend = try JsBackend.new(std.testing.allocator);
        defer backend.deinit();

        try emitDecl(&backend, decl.data.Decl);

        const str = try backend.toString();
        defer backend.freeString(str);
        try expectEqualStrings(self.expectedOutput, str);
    }

    pub fn makeNode(comptime ty: node.NodeType, data: anytype) !Node {
        return node.makeNode(
            std.testing.allocator,
            Cursor.new(0, 0),
            ty,
            data,
        );
    }
};

test "JsBackend can emit var declaration" {
    try (DeclTestCase{
        .inputTy = "var",
        .scoping = .Var,
        .expectedOutput = "var test = null;\n",
    }).run();
}

test "JsBackend can emit let declaration" {
    try (DeclTestCase{
        .inputTy = "let",
        .scoping = .Let,
        .expectedOutput = "let test = null;\n",
    }).run();
}

test "JsBackend can emit const declaration" {
    try (DeclTestCase{
        .inputTy = "const",
        .scoping = .Const,
        .expectedOutput = "const test = null;\n",
    }).run();
}
