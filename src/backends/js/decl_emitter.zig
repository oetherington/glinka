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

pub fn emitDecl(
    self: *JsBackend,
    ty: []const u8,
    decl: node.Decl,
) Backend.Error!void {
    try self.out.print("{s} {s}", .{ ty, decl.name });

    if (decl.value) |value| {
        try self.out.print(" = ", .{});
        try self.emitExpr(value);
    }

    try self.out.print(";\n", .{});
}

fn DeclTestCase(comptime declType: node.NodeType) type {
    return struct {
        const This = @This();

        inputTy: []const u8,
        getData: fn (nd: Node) node.Decl,
        expectedOutput: []const u8,

        pub fn run(self: This) !void {
            var value = try This.makeNode(.Null, {});
            defer std.testing.allocator.destroy(value);

            var decl = try This.makeNode(
                declType,
                node.Decl.new("test", null, value),
            );
            defer std.testing.allocator.destroy(decl);

            var backend = try JsBackend.new(std.testing.allocator);
            defer backend.deinit();

            try emitDecl(&backend, self.inputTy, self.getData(decl));

            const str = try backend.toString();
            defer backend.freeString(str);
            try expectEqualStrings(self.expectedOutput, str);
        }

        pub fn makeNode(comptime ty: node.NodeType, data: anytype) !Node {
            return try node.makeNode(
                std.testing.allocator,
                Cursor.new(0, 0),
                ty,
                data,
            );
        }

        pub fn getVar(nd: Node) node.Decl {
            return nd.data.Var;
        }

        pub fn getLet(nd: Node) node.Decl {
            return nd.data.Let;
        }

        pub fn getConst(nd: Node) node.Decl {
            return nd.data.Const;
        }
    };
}

test "JsBackend can emit var declaration" {
    const TestCase = DeclTestCase(.Var);
    try (TestCase{
        .inputTy = "var",
        .getData = TestCase.getVar,
        .expectedOutput = "var test = null;\n",
    }).run();
}

test "JsBackend can emit let declaration" {
    const TestCase = DeclTestCase(.Let);
    try (TestCase{
        .inputTy = "let",
        .getData = TestCase.getLet,
        .expectedOutput = "let test = null;\n",
    }).run();
}

test "JsBackend can emit const declaration" {
    const TestCase = DeclTestCase(.Const);
    try (TestCase{
        .inputTy = "const",
        .getData = TestCase.getConst,
        .expectedOutput = "const test = null;\n",
    }).run();
}
