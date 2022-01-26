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
const Allocator = std.mem.Allocator;
const node = @import("../../common/node.zig");
const Node = node.Node;
const Cursor = @import("../../common/cursor.zig").Cursor;
const Backend = @import("../../common/backend.zig").Backend;
const JsBackend = @import("js_backend.zig").JsBackend;
const EmitTestCase = @import("emit_test_case.zig").EmitTestCase;

pub fn emitClass(self: *JsBackend, class: node.ClassType) Backend.Error!void {
    try self.out.print(
        "var {s} = /** @class */ (function (_super) {{\n",
        .{class.name},
    );

    if (class.extends != null)
        try self.out.print(" __extends({s}, _super);\n", .{class.name});

    try self.out.print(" function {s}() {{\n", .{class.name});
    if (class.extends != null)
        try self.out.print(
            "  return _super !== null && _super.apply(this, arguments) || this;\n",
            .{},
        );
    try self.out.print(" }}\n", .{});

    for (class.members.items) |member| {
        const mem = member.data.ClassTypeMember;
        if (mem.value) |value| {
            try self.out.print(" {s}.{s} = ", .{ class.name, mem.name });
            try self.emitExpr(value);
            try self.out.print(";\n", .{});
        }
    }

    try self.out.print(" return {s};\n", .{class.name});
    try self.out.print(
        "}}({s}));\n",
        .{if (class.extends) |extends| extends else ""},
    );
}

test "JsBackend can emit empty class" {
    var class = node.ClassType.new("MyClass", null);

    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.ClassType, class),
        .expectedOutput = 
        \\var MyClass = /** @class */ (function (_super) {
        \\ function MyClass() {
        \\ }
        \\ return MyClass;
        \\}());
        \\
        ,
    }).run();
}

test "JsBackend can emit class with superclass" {
    var class = node.ClassType.new("MyClass", "SomeOtherClass");

    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.ClassType, class),
        .expectedOutput = 
        \\var MyClass = /** @class */ (function (_super) {
        \\ __extends(MyClass, _super);
        \\ function MyClass() {
        \\  return _super !== null && _super.apply(this, arguments) || this;
        \\ }
        \\ return MyClass;
        \\}(SomeOtherClass));
        \\
        ,
    }).run();
}

test "JsBackend can emit class with initialized members" {
    var class = node.ClassType.new("MyClass", null);

    class.members = node.NodeList{
        .items = &[_]node.Node{
            EmitTestCase.makeNode(.ClassTypeMember, node.ClassTypeMember{
                .isStatic = false,
                .isReadOnly = false,
                .visibility = .Public,
                .name = "aClassMember",
                .ty = null,
                .value = EmitTestCase.makeNode(.Int, "3"),
            }),
        },
    };

    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.ClassType, class),
        .expectedOutput = 
        \\var MyClass = /** @class */ (function (_super) {
        \\ function MyClass() {
        \\ }
        \\ MyClass.aClassMember = 3;
        \\ return MyClass;
        \\}());
        \\
        ,
        .cleanup = (struct {
            pub fn cleanup(alloc: Allocator, nd: Node) void {
                const members = nd.data.ClassType.members.items;
                alloc.destroy(members[0].data.ClassTypeMember.value.?);
                alloc.destroy(members[0]);
            }
        }).cleanup,
    }).run();
}
