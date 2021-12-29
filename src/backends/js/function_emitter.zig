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
const node = @import("../../common/node.zig");
const Node = node.Node;
const Cursor = @import("../../common/cursor.zig").Cursor;
const Backend = @import("../../common/backend.zig").Backend;
const JsBackend = @import("js_backend.zig").JsBackend;
const EmitTestCase = @import("emit_test_case.zig").EmitTestCase;

pub fn emitFunc(self: *JsBackend, func: node.Function) Backend.Error!void {
    std.debug.assert(!func.isArrow); // TODO: Implement arrow functions
    std.debug.assert(func.body.getType() == .Block);

    try self.out.print("function {s}(", .{if (func.name) |name| name else ""});

    var prefix: []const u8 = "";
    for (func.args.items) |arg| {
        try self.out.print("{s}{s}", .{ prefix, arg.name });
        prefix = ", ";
    }

    try self.out.print(") ", .{});

    try self.emitNode(func.body);
}

test "JsBackend can emit function" {
    const alloc = std.testing.allocator;

    var func = node.Function{
        .isArrow = false,
        .name = "aFunction",
        .retTy = null,
        .args = .{},
        .body = EmitTestCase.makeNode(.Block, node.NodeList{}),
    };

    defer alloc.destroy(func.body);
    defer func.args.deinit(alloc);

    try func.args.append(alloc, .{
        .csr = Cursor.new(0, 0),
        .name = "a",
        .ty = null,
    });

    try func.args.append(alloc, .{
        .csr = Cursor.new(0, 0),
        .name = "b",
        .ty = null,
    });

    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Function, func),
        .expectedOutput = "function aFunction(a, b) {\n}\n",
    }).run();
}

pub fn emitReturn(self: *JsBackend, expr: ?Node) Backend.Error!void {
    if (expr) |val| {
        try self.out.print("return ", .{});
        try self.emitExpr(val);
        try self.out.print(";\n", .{});
    } else {
        try self.out.print("return;\n", .{});
    }
}

test "JsBackend can emit return without a value" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Return, null),
        .expectedOutput = "return;\n",
    }).run();
}

test "JsBackend can emit return with a value" {
    const alloc = std.testing.allocator;
    const value = EmitTestCase.makeNode(.Null, {});
    defer alloc.destroy(value);

    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Return, value),
        .expectedOutput = "return null;\n",
    }).run();
}
