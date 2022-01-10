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

    pub fn getNamedMember(
        self: InterfaceType,
        name: []const u8,
    ) ?Member {
        for (self.members) |member|
            if (std.mem.eql(u8, member.name, name))
                return member;

        return null;
    }

    pub fn isAssignableTo(self: InterfaceType, target: InterfaceType) bool {
        for (target.members) |member| {
            const local = self.getNamedMember(member.name);
            if (local) |local_| {
                if (!local_.ty.isAssignableTo(member.ty))
                    return false;
            } else {
                return false;
            }
        }

        return true;
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

test "can retrieve InterfaceType member by name" {
    const num = Type.newNumber();
    const str = Type.newString();

    const in = Type.InterfaceType.new(&[_]Type.InterfaceType.Member{
        Type.InterfaceType.Member{ .name = "a", .ty = &num },
        Type.InterfaceType.Member{ .name = "b", .ty = &str },
    });

    const a = in.getNamedMember("a");
    try std.testing.expect(a != null);
    try std.testing.expectEqualStrings("a", a.?.name);
    try std.testing.expectEqual(Type.Type.Number, a.?.ty.getType());

    const b = in.getNamedMember("b");
    try std.testing.expect(b != null);
    try std.testing.expectEqualStrings("b", b.?.name);
    try std.testing.expectEqual(Type.Type.String, b.?.ty.getType());

    const c = in.getNamedMember("c");
    try std.testing.expect(c == null);
}

test "can check if interface assignablility" {
    const num = Type.newNumber();
    const str = Type.newString();
    const any = Type.newAny();

    const a = Type.InterfaceType.new(&[_]Type.InterfaceType.Member{
        Type.InterfaceType.Member{ .name = "a", .ty = &num },
        Type.InterfaceType.Member{ .name = "b", .ty = &str },
    });

    const b = Type.InterfaceType.new(&[_]Type.InterfaceType.Member{
        Type.InterfaceType.Member{ .name = "a", .ty = &num },
        Type.InterfaceType.Member{ .name = "b", .ty = &str },
        Type.InterfaceType.Member{ .name = "c", .ty = &any },
    });

    const c = Type.InterfaceType.new(&[_]Type.InterfaceType.Member{
        Type.InterfaceType.Member{ .name = "a", .ty = &any },
        Type.InterfaceType.Member{ .name = "b", .ty = &str },
    });

    try std.testing.expect(a.isAssignableTo(a));
    try std.testing.expect(!a.isAssignableTo(b));
    try std.testing.expect(a.isAssignableTo(c));
    try std.testing.expect(b.isAssignableTo(a));
    try std.testing.expect(b.isAssignableTo(b));
    try std.testing.expect(b.isAssignableTo(c));
    try std.testing.expect(!c.isAssignableTo(a));
    try std.testing.expect(!c.isAssignableTo(b));
    try std.testing.expect(c.isAssignableTo(c));
}
