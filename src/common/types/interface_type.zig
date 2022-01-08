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
const genericEql = @import("../generic_eql.zig").eql;
const Type = @import("type.zig").Type;

pub const InterfaceType = struct {
    pub const Member = struct {
        name: []const u8,
        ty: Type.Ptr,

        pub fn eql(a: Member, b: Member) bool {
            return genericEql(a, b);
        }
    };

    members: []Member,

    pub fn new(members: []Member) InterfaceType {
        return InterfaceType{
            .members = members,
        };
    }

    pub fn hash(self: InterfaceType) usize {
        var result: usize = 0xe75f7630fbf1ff65;

        for (self.members) |mem|
            result ^= std.hash.Wyhash.hash(0, mem.name) ^ @ptrToInt(mem.ty);

        return result;
    }

    pub fn write(self: InterfaceType, writer: anytype) !void {
        try writer.print("{{ ", .{});

        for (self.members) |mem| {
            try writer.print("{s}: ", .{mem.name});
            try mem.ty.write(writer);
            try writer.print(", ", .{});
        }

        try writer.print("}}", .{});
    }
};

test "can check InterfaceType.Member equality" {
    const number = Type.newNumber();
    const boolean = Type.newBoolean();
    const a = InterfaceType.Member{ .name = "a", .ty = &number };
    const b = InterfaceType.Member{ .name = "a", .ty = &number };
    const c = InterfaceType.Member{ .name = "b", .ty = &number };
    const d = InterfaceType.Member{ .name = "a", .ty = &boolean };

    try std.testing.expect(a.eql(a));
    try std.testing.expect(a.eql(b));
    try std.testing.expect(!a.eql(c));
    try std.testing.expect(!a.eql(d));
}

test "can hash an InterfaceType" {
    const num = Type.newNumber();
    const str = Type.newString();
    const never = Type.newNever();

    const a = Type.InterfaceType.new(&[_]Type.InterfaceType.Member{
        Type.InterfaceType.Member{ .name = "a", .ty = &num },
        Type.InterfaceType.Member{ .name = "b", .ty = &str },
    });
    const b = Type.InterfaceType.new(&[_]Type.InterfaceType.Member{
        Type.InterfaceType.Member{ .name = "b", .ty = &str },
        Type.InterfaceType.Member{ .name = "a", .ty = &num },
    });
    const c = Type.InterfaceType.new(&[_]Type.InterfaceType.Member{
        Type.InterfaceType.Member{ .name = "a", .ty = &num },
        Type.InterfaceType.Member{ .name = "b", .ty = &never },
    });

    try std.testing.expectEqual(a.hash(), a.hash());
    try std.testing.expectEqual(a.hash(), b.hash());
    try std.testing.expect(a.hash() != c.hash());
}
