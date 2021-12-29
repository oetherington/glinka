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

pub fn emitThrow(self: *JsBackend, expr: Node) Backend.Error!void {
    try self.out.print("throw ", .{});
    try self.emitExpr(expr);
    try self.out.print(";\n", .{});
}

test "JsBackend can emit throw statements" {
    const expr = EmitTestCase.makeNode(.True, {});
    defer std.testing.allocator.destroy(expr);

    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Throw, expr),
        .expectedOutput = "throw true;\n",
    }).run();
}

pub fn emitTry(self: *JsBackend, data: node.Try) Backend.Error!void {
    try self.out.print("try ", .{});
    try self.emitNode(data.tryBlock);

    for (data.catchBlocks.items) |catchBlock| {
        try self.out.print("catch ({s}) ", .{catchBlock.name});
        try self.emitNode(catchBlock.block);
    }

    if (data.finallyBlock) |finallyBlock| {
        try self.out.print("finally ", .{});
        try self.emitNode(finallyBlock);
    }
}

test "JsBackend can emit try statements" {
    const expr1 = EmitTestCase.makeNode(.True, {});
    const expr2 = EmitTestCase.makeNode(.False, {});
    const expr3 = EmitTestCase.makeNode(.Null, {});
    const expr4 = EmitTestCase.makeNode(.Undefined, {});
    defer std.testing.allocator.destroy(expr1);
    defer std.testing.allocator.destroy(expr2);
    defer std.testing.allocator.destroy(expr3);
    defer std.testing.allocator.destroy(expr4);

    var data = node.Try{
        .tryBlock = expr1,
        .catchBlocks = .{
            .items = &[_]node.Try.Catch{
                .{
                    .name = "e",
                    .block = expr2,
                },
                .{
                    .name = "f",
                    .block = expr3,
                },
            },
        },
        .finallyBlock = expr4,
    };

    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Try, data),
        .expectedOutput = 
        \\try true;
        \\catch (e) false;
        \\catch (f) null;
        \\finally undefined;
        \\
        ,
    }).run();
}
