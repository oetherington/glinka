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

pub fn emitFor(self: *JsBackend, loop: node.For) Backend.Error!void {
    try self.out.print("for (", .{});

    switch (loop.clause) {
        .CStyle => |c| {
            try self.emitNode(c.pre);
            try self.emitExpr(c.cond);
            try self.out.print(";\n", .{});
            try self.emitExpr(c.post);
        },
        .Each => |each| {
            try self.out.print("{s} {s} {s} ", .{
                each.scoping.toString(),
                each.name,
                each.variant.toString(),
            });
            try self.emitExpr(each.expr);
        },
    }

    try self.out.print(") ", .{});
    try self.emitNode(loop.body);
}

test "JsBackend can emit c-style for loop" {
    const alloc = std.testing.allocator;

    const pre = EmitTestCase.makeNode(.True, {});
    const cond = EmitTestCase.makeNode(.False, {});
    const post = EmitTestCase.makeNode(.Undefined, {});
    const body = EmitTestCase.makeNode(.Null, {});
    defer alloc.destroy(pre);
    defer alloc.destroy(cond);
    defer alloc.destroy(post);
    defer alloc.destroy(body);

    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.For, node.For{
            .clause = .{
                .CStyle = .{
                    .pre = pre,
                    .cond = cond,
                    .post = post,
                },
            },
            .body = body,
        }),
        .expectedOutput = "for (true;\nfalse;\nundefined) null;\n",
    }).run();
}

test "JsBackend can emit for each loop" {
    const alloc = std.testing.allocator;

    const expr = EmitTestCase.makeNode(.True, {});
    const body = EmitTestCase.makeNode(.Null, {});
    defer alloc.destroy(expr);
    defer alloc.destroy(body);

    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.For, node.For{
            .clause = .{
                .Each = .{
                    .scoping = .Let,
                    .variant = .Of,
                    .name = "a",
                    .expr = expr,
                },
            },
            .body = body,
        }),
        .expectedOutput = "for (let a of true) null;\n",
    }).run();
}

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

pub fn emitBreak(self: *JsBackend, label: ?[]const u8) Backend.Error!void {
    try if (label) |l|
        self.out.print("break {s};\n", .{l})
    else
        self.out.print("break;\n", .{});
}

test "JsBackend can emit 'break' statement" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Break, null),
        .expectedOutput = "break;\n",
    }).run();
}

test "JsBackend can emit 'break' statement with a label" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Break, "aLabel"),
        .expectedOutput = "break aLabel;\n",
    }).run();
}

pub fn emitContinue(self: *JsBackend, label: ?[]const u8) Backend.Error!void {
    try if (label) |l|
        self.out.print("continue {s};\n", .{l})
    else
        self.out.print("continue;\n", .{});
}

test "JsBackend can emit 'continue' statement" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Continue, null),
        .expectedOutput = "continue;\n",
    }).run();
}

test "JsBackend can emit 'continue' statement with a label" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Continue, "aLabel"),
        .expectedOutput = "continue aLabel;\n",
    }).run();
}
