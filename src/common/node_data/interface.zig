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

pub const InterfaceTypeMember = struct {
    name: []const u8,
    ty: Node,

    pub fn new(name: []const u8, ty: Node) InterfaceTypeMember {
        return InterfaceTypeMember{
            .name = name,
            .ty = ty,
        };
    }

    pub fn eql(self: InterfaceTypeMember, other: InterfaceTypeMember) bool {
        return genericEql.eql(self, other);
    }

    pub fn dump(
        self: InterfaceTypeMember,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "Member: {s}\n", .{self.name});
        try self.ty.dumpIndented(writer, indent + 2);
    }
};

test "can compare InterfaceTypeMembers for equality" {
    const node = makeNode(
        std.testing.allocator,
        Cursor.new(1, 1),
        .TypeName,
        "int",
    );
    defer std.testing.allocator.destroy(node);

    const a = InterfaceTypeMember.new("a", node);
    const b = InterfaceTypeMember.new("a", node);
    const c = InterfaceTypeMember.new("b", node);

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

pub const InterfaceTypeMemberList = std.ArrayListUnmanaged(InterfaceTypeMember);

pub const InterfaceType = struct {
    name: ?[]const u8,
    members: InterfaceTypeMemberList,
};

test "can dump an InterfaceType" {
    const node = makeNode(
        std.testing.allocator,
        Cursor.new(1, 1),
        .TypeName,
        "string",
    );
    defer std.testing.allocator.destroy(node);

    try (DumpTestCase(InterfaceType, .InterfaceType){
        .value = InterfaceType{
            .name = "anInterface",
            .members = .{
                .items = &[_]InterfaceTypeMember{
                    InterfaceTypeMember.new("a", node),
                    InterfaceTypeMember.new("b", node),
                },
            },
        },
        .expected = 
        \\InterfaceType anInterface
        \\  Member: a
        \\    TypeName Node (1:1)
        \\      TypeName: "string"
        \\  Member: b
        \\    TypeName Node (1:1)
        \\      TypeName: "string"
        \\
        ,
    }).run();
}
