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

pub fn emitClass(self: *JsBackend, class: node.ClassType) Backend.Error!void {
    try self.out.print("class {s} ", .{class.name});

    if (class.extends) |extends|
        try self.out.print("extends {s} ", .{extends});

    try self.out.print("{{\n", .{});
    try self.out.print("}}\n", .{});
}

test "JsBackend can emit class" {
    var class = node.ClassType.new("MyClass", "SomeOtherClass");

    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.ClassType, class),
        .expectedOutput = "class MyClass extends SomeOtherClass {\n}\n",
    }).run();
}
