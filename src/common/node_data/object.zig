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
const expectEqualStrings = std.testing.expectEqualStrings;
const genericEql = @import("../generic_eql.zig");
const Cursor = @import("../cursor.zig").Cursor;
const putInd = @import("indenter.zig").putInd;
const DumpTestCase = @import("dump_test_case.zig").DumpTestCase;
const nodeImp = @import("../node.zig");
const Node = nodeImp.Node;
const makeNode = nodeImp.makeNode;

pub const ObjectProperty = struct {
    key: Node,
    value: Node,

    pub fn new(key: Node, value: Node) ObjectProperty {
        return ObjectProperty{
            .key = key,
            .value = value,
        };
    }

    pub fn getName(self: ObjectProperty) []const u8 {
        return switch (self.key.data) {
            .Ident => |id| id,
            .String => |str| str[1 .. str.len - 1],
            else => std.debug.panic(
                "Invalid ObjectProperty key type: {s}",
                .{self.key.getType()},
            ),
        };
    }

    pub fn dump(
        self: ObjectProperty,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "Property\n", .{});
        try self.key.dumpIndented(writer, indent + 2);
        try self.value.dumpIndented(writer, indent + 2);
    }

    pub fn eql(self: ObjectProperty, other: ObjectProperty) bool {
        return genericEql.eql(self, other);
    }
};

test "can retrieve ObjectProperty name" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Ident, "anIdent"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .String, "'aString'"),
        makeNode(std.testing.allocator, Cursor.new(3, 1), .Int, "0"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    const anIdentKeyProp = ObjectProperty.new(nodes[0], nodes[2]);
    const aStringKeyProp = ObjectProperty.new(nodes[1], nodes[2]);

    try expectEqualStrings("anIdent", anIdentKeyProp.getName());
    try expectEqualStrings("aString", aStringKeyProp.getName());
}

test "can compare ObjectProperties for equality" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .String, "'a'"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .String, "'1'"),
        makeNode(std.testing.allocator, Cursor.new(3, 1), .String, "'b'"),
        makeNode(std.testing.allocator, Cursor.new(4, 1), .String, "'2'"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    const a = ObjectProperty.new(nodes[0], nodes[1]);
    const b = ObjectProperty.new(nodes[0], nodes[1]);
    const c = ObjectProperty.new(nodes[2], nodes[3]);

    try expect(a.eql(a));
    try expect(a.eql(b));
    try expect(!a.eql(c));
    try expect(b.eql(a));
    try expect(b.eql(b));
    try expect(!b.eql(c));
    try expect(!c.eql(a));
    try expect(!c.eql(b));
    try expect(c.eql(c));
}

pub const Object = std.ArrayListUnmanaged(ObjectProperty);

test "can dump an Object" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .String, "'a'"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .String, "1"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(Object, .Object){
        .value = Object{ .items = &[_]ObjectProperty{
            ObjectProperty.new(nodes[0], nodes[1]),
        } },
        .expected = 
        \\Object
        \\  Property
        \\    String Node (1:1)
        \\      String: "'a'"
        \\    String Node (2:1)
        \\      String: "1"
        \\
        ,
    }).run();
}
