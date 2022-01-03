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
const WriteContext = @import("../writer.zig").WriteContext;
const Type = @import("type.zig").Type;

pub const AliasType = struct {
    name: []const u8,
    ty: Type.Ptr,

    pub fn new(name: []const u8, ty: Type.Ptr) AliasType {
        return AliasType{
            .name = name,
            .ty = ty,
        };
    }

    pub fn hash(self: AliasType) usize {
        return std.hash.Wyhash.hash(0, self.name) ^ @ptrToInt(self.ty);
    }

    pub fn write(self: AliasType, writer: anytype) !void {
        try writer.print("{s} (an alias for ", .{self.name});
        try self.ty.write(writer);
        try writer.print(")", .{});
    }
};

test "can hash AliasType" {
    const number = Type.newNumber();
    const string = Type.newString();

    const a = AliasType.new("a", &number);
    const b = AliasType.new("a", &number);
    const c = AliasType.new("a", &string);
    const d = AliasType.new("b", &number);
    const e = AliasType.new("c", &string);

    try expect(a.hash() == b.hash());
    try expect(a.hash() != c.hash());
    try expect(a.hash() != d.hash());
    try expect(a.hash() != e.hash());
}

test "can write AliasType" {
    const ctx = try WriteContext(.{}).new(std.testing.allocator);
    defer ctx.deinit();

    const number = Type.newNumber();
    const ty = AliasType.new("SomeTypeName", &number);

    try ty.write(ctx.writer());

    const str = try ctx.toString();
    defer ctx.freeString(str);

    try std.testing.expectEqualStrings(
        "SomeTypeName (an alias for number)",
        str,
    );
}
