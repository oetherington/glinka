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

pub fn emitBlock(self: *JsBackend, children: []const Node) Backend.Error!void {
    try self.out.print("{{\n", .{});

    for (children) |child|
        try self.emitNode(child);

    try self.out.print("}}\n", .{});
}

test "JsBackend can emit empty blocks" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Block, node.NodeList{}),
        .expectedOutput = "{\n}\n",
    }).run();
}

test "JsBackend can emit populated blocks" {
    const alloc = std.testing.allocator;

    var children = node.NodeList{};
    defer children.deinit(alloc);

    try children.append(alloc, EmitTestCase.makeNode(.Null, {}));
    defer alloc.destroy(children.items[0]);

    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Block, children),
        .expectedOutput = "{\nnull;\n}\n",
    }).run();
}
