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
const node = @import("../../common/node.zig");
const Node = node.Node;
const Cursor = @import("../../common/cursor.zig").Cursor;
const Backend = @import("../../common/backend.zig").Backend;
const JsBackend = @import("js_backend.zig").JsBackend;
const EmitTestCase = @import("emit_test_case.zig").EmitTestCase;

pub fn emitWhile(self: *JsBackend, loop: node.While) Backend.Error!void {
    try self.out.print("while (", .{});
    try self.emitExpr(loop.cond);
    try self.out.print(") ", .{});
    try self.emitNode(loop.body);
}

test "JsBackend can emit 'while' statement" {
    const alloc = std.testing.allocator;

    const cond = EmitTestCase.makeNode(.True, {});
    const body = EmitTestCase.makeNode(.Null, {});
    defer alloc.destroy(cond);
    defer alloc.destroy(body);

    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.While, node.While{
            .cond = cond,
            .body = body,
        }),
        .expectedOutput = "while (true) null;\n",
    }).run();
}

pub fn emitDo(self: *JsBackend, loop: node.Do) Backend.Error!void {
    try self.out.print("do ", .{});
    try self.emitNode(loop.body);
    try self.out.print("while (", .{});
    try self.emitExpr(loop.cond);
    try self.out.print(");\n", .{});
}

test "JsBackend can emit 'do' statement" {
    const alloc = std.testing.allocator;

    const body = EmitTestCase.makeNode(.Null, {});
    const cond = EmitTestCase.makeNode(.True, {});
    defer alloc.destroy(body);
    defer alloc.destroy(cond);

    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Do, node.Do{
            .body = body,
            .cond = cond,
        }),
        .expectedOutput = "do null;\nwhile (true);\n",
    }).run();
}
