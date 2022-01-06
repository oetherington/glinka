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
const Type = @import("type.zig").Type;

pub const UnionType = struct {
    tys: []Type.Ptr,

    pub fn new(tys: []Type.Ptr) UnionType {
        return UnionType{
            .tys = tys,
        };
    }

    pub fn hash(self: UnionType) usize {
        var result: usize = 0xc55d0505bb5a5d99;

        for (self.tys) |ty|
            result ^= ty.hash();

        return result;
    }

    pub fn contains(self: UnionType, ty: Type.Ptr) bool {
        for (self.tys) |t|
            if (t == ty)
                return true;

        return false;
    }

    pub fn write(self: UnionType, writer: anytype) !void {
        var prefix: []const u8 = "";
        for (self.tys) |ty| {
            try writer.print("{s}", .{prefix});
            try ty.write(writer);
            prefix = "|";
        }
    }
};

test "can hash a UnionType" {
    const num = Type.newNumber();
    const str = Type.newString();
    const never = Type.newNever();

    const a = UnionType.new(&[_]Type.Ptr{ &num, &str });
    const b = UnionType.new(&[_]Type.Ptr{ &num, &never });

    try std.testing.expectEqual(a.hash(), a.hash());
    try std.testing.expect(a.hash() != b.hash());
}
