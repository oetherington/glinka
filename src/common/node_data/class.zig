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
const expect = std.testing.expect;
const genericEql = @import("../generic_eql.zig");
const Cursor = @import("../cursor.zig").Cursor;
const putInd = @import("indenter.zig").putInd;
const DumpTestCase = @import("dump_test_case.zig").DumpTestCase;
const nodeImp = @import("../node.zig");
const Node = nodeImp.Node;
const makeNode = nodeImp.makeNode;

pub const Visibility = enum {
    Public,
    Protected,
    Private,
};

pub const ClassTypeMethod = struct {};
pub const ClassTypeMember = struct {};

pub const ClassTypeMethodList = std.ArrayListUnmanaged(ClassTypeMethod);
pub const ClassTypeMemberList = std.ArrayListUnmanaged(ClassTypeMember);

pub const ClassType = struct {
    name: []const u8,
    extends: ?[]const u8,
    constructor: ?ClassTypeMethod,
    destructor: ?ClassTypeMethod,
    methods: ClassTypeMethodList,
    members: ClassTypeMemberList,

    pub fn new(name: []const u8, extends: ?[]const u8) ClassType {
        return ClassType{
            .name = name,
            .extends = extends,
            .constructor = null,
            .destructor = null,
            .methods = ClassTypeMethodList{ .items = &[_]ClassTypeMethod{} },
            .members = ClassTypeMemberList{ .items = &[_]ClassTypeMember{} },
        };
    }

    pub fn dump(self: ClassType, writer: anytype, indent: usize) !void {
        try putInd(writer, indent, "ClassType '{s}'\n", .{self.name});
        if (self.extends) |extends|
            try putInd(writer, indent + 2, "Extends '{s}'\n", .{extends});
    }
};

test "can dump a ClassType" {
    try (DumpTestCase(ClassType, .ClassType){
        .value = ClassType.new("MyClass", "SomeOtherClass"),
        .expected = 
        \\ClassType 'MyClass'
        \\  Extends 'SomeOtherClass'
        \\
        ,
    }).run();
}
