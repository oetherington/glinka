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
const Visibility = @import("../visibility.zig").Visibility;

pub const ClassType = struct {
    pub const Member = struct {
        // TODO: static, readonly, initialization values
        name: []const u8,
        ty: Type.Ptr,
        visibility: Visibility,

        pub fn eql(a: Member, b: Member) bool {
            return genericEql(a, b);
        }
    };

    super: ?Type.Ptr,
    name: []const u8,
    members: []Member,

    pub fn new(
        super: ?Type.Ptr,
        name: []const u8,
        members: []Member,
    ) ClassType {
        std.debug.assert(super == null or super.?.getType() == .Class);

        return ClassType{
            .super = super,
            .name = name,
            .members = members,
        };
    }

    pub fn hash(self: ClassType) usize {
        var result: usize = if (self.super) |super|
            super.hash()
        else
            0x0e28e786568bc7a6;

        result ^= std.hash.Wyhash.hash(0, self.name);

        for (self.members) |mem| {
            result ^= std.hash.Wyhash.hash(0, mem.name);
            result ^= @ptrToInt(mem.ty);
            result += @enumToInt(mem.visibility);
        }

        return result;
    }

    pub fn write(self: ClassType, writer: anytype) !void {
        try writer.print("class {s}", .{self.name});
    }

    pub fn getNamedMember(
        self: ClassType,
        name: []const u8,
    ) ?Member {
        for (self.members) |member|
            if (std.mem.eql(u8, member.name, name))
                return member;

        if (self.super) |super|
            return super.Class.getNamedMember(name);

        return null;
    }

    pub fn isSubclassOf(self: ClassType, super: Type.Ptr) bool {
        if (super.getType() != .Class)
            return false;

        var s = self.super;
        while (s) |ss| {
            std.debug.assert(ss.getType() == .Class);
            if (super == ss)
                return true;
            s = ss.Class.super;
        }

        return false;
    }
};

test "can check ClassType.Member equality" {
    const number = Type.newNumber();
    const boolean = Type.newBoolean();
    const a = ClassType.Member{
        .name = "a",
        .ty = &number,
        .visibility = .Public,
    };
    const b = ClassType.Member{
        .name = "a",
        .ty = &number,
        .visibility = .Public,
    };
    const c = ClassType.Member{
        .name = "b",
        .ty = &number,
        .visibility = .Public,
    };
    const d = ClassType.Member{
        .name = "a",
        .ty = &boolean,
        .visibility = .Public,
    };
    const e = ClassType.Member{
        .name = "a",
        .ty = &number,
        .visibility = .Protected,
    };

    try std.testing.expect(a.eql(a));
    try std.testing.expect(a.eql(b));
    try std.testing.expect(!a.eql(c));
    try std.testing.expect(!a.eql(d));
    try std.testing.expect(!a.eql(e));
}

test "can hash a ClassType" {
    const num = Type.newNumber();
    const str = Type.newString();

    const a = Type.ClassType.new(null, "A", &[_]Type.ClassType.Member{
        Type.ClassType.Member{ .name = "a", .ty = &num, .visibility = .Public },
        Type.ClassType.Member{ .name = "b", .ty = &str, .visibility = .Public },
    });
    const b = Type.ClassType.new(null, "A", &[_]Type.ClassType.Member{
        Type.ClassType.Member{ .name = "a", .ty = &num, .visibility = .Public },
        Type.ClassType.Member{ .name = "b", .ty = &str, .visibility = .Public },
    });
    const super = Type.newClass(a);
    const c = Type.ClassType.new(&super, "A", &[_]Type.ClassType.Member{
        Type.ClassType.Member{ .name = "a", .ty = &num, .visibility = .Public },
        Type.ClassType.Member{ .name = "b", .ty = &str, .visibility = .Public },
    });
    const d = Type.ClassType.new(null, "B", &[_]Type.ClassType.Member{
        Type.ClassType.Member{ .name = "a", .ty = &num, .visibility = .Public },
        Type.ClassType.Member{ .name = "b", .ty = &str, .visibility = .Public },
    });
    const e = Type.ClassType.new(null, "B", &[_]Type.ClassType.Member{
        Type.ClassType.Member{ .name = "a", .ty = &num, .visibility = .Public },
    });
    const f = Type.ClassType.new(null, "B", &[_]Type.ClassType.Member{
        Type.ClassType.Member{ .name = "a", .ty = &num, .visibility = .Public },
        Type.ClassType.Member{ .name = "b", .ty = &num, .visibility = .Public },
    });

    try std.testing.expectEqual(a.hash(), a.hash());
    try std.testing.expectEqual(a.hash(), b.hash());
    try std.testing.expect(a.hash() != c.hash());
    try std.testing.expect(a.hash() != d.hash());
    try std.testing.expect(a.hash() != e.hash());
    try std.testing.expect(a.hash() != f.hash());
}

test "can retrieve ClassType member by name" {
    const num = Type.newNumber();
    const str = Type.newString();

    const c0 = Type.ClassType.new(null, "A", &[_]Type.ClassType.Member{
        Type.ClassType.Member{ .name = "a", .ty = &num, .visibility = .Public },
        Type.ClassType.Member{ .name = "b", .ty = &str, .visibility = .Public },
    });
    const super = Type.newClass(c0);
    const c1 = Type.ClassType.new(&super, "B", &[_]Type.ClassType.Member{
        Type.ClassType.Member{ .name = "c", .ty = &num, .visibility = .Public },
        Type.ClassType.Member{ .name = "d", .ty = &str, .visibility = .Public },
    });

    const a = c0.getNamedMember("a");
    try std.testing.expect(a != null);
    try std.testing.expectEqualStrings("a", a.?.name);
    try std.testing.expectEqual(Type.Type.Number, a.?.ty.getType());

    const b = c1.getNamedMember("b");
    try std.testing.expect(b != null);
    try std.testing.expectEqualStrings("b", b.?.name);
    try std.testing.expectEqual(Type.Type.String, b.?.ty.getType());

    const c = c0.getNamedMember("c");
    try std.testing.expect(c == null);
}

test "can detect if a class is a subclass of another class" {
    const c0 = Type.newClass(
        Type.ClassType.new(null, "A", &[_]Type.ClassType.Member{}),
    );
    const c1 = Type.newClass(
        Type.ClassType.new(null, "B", &[_]Type.ClassType.Member{}),
    );
    const c2 = Type.newClass(
        Type.ClassType.new(&c0, "C", &[_]Type.ClassType.Member{}),
    );
    const c3 = Type.newClass(
        Type.ClassType.new(&c2, "D", &[_]Type.ClassType.Member{}),
    );

    try std.testing.expect(!c0.Class.isSubclassOf(&c1));
    try std.testing.expect(!c1.Class.isSubclassOf(&c0));
    try std.testing.expect(!c0.Class.isSubclassOf(&c2));
    try std.testing.expect(c2.Class.isSubclassOf(&c0));
    try std.testing.expect(!c0.Class.isSubclassOf(&c3));
    try std.testing.expect(c3.Class.isSubclassOf(&c2));
    try std.testing.expect(c3.Class.isSubclassOf(&c0));
}
