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

    pub fn write(self: AliasType, writer: anytype) !void {
        try writer.print("{s} (an alias for ", .{self.name});
        try self.ty.write(writer);
        try writer.print(")", .{});
    }
};

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
