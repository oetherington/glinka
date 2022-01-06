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

pub const ArrayType = struct {
    subtype: Type.Ptr,

    pub fn new(subtype: Type.Ptr) ArrayType {
        return ArrayType{
            .subtype = subtype,
        };
    }

    pub fn hash(self: ArrayType) usize {
        return self.subtype.hash() ^ 0x54915bee0f3e544b;
    }

    pub fn write(self: ArrayType, writer: anytype) !void {
        if (self.subtype.getType() == .Union) {
            try writer.print("(", .{});
            try self.subtype.write(writer);
            try writer.print(")[]", .{});
        } else {
            try self.subtype.write(writer);
            try writer.print("[]", .{});
        }
    }
};

test "can hash an ArrayType" {
    const str = Type.newString();
    const num = Type.newNumber();

    const a = ArrayType.new(&str);
    const b = ArrayType.new(&num);

    try std.testing.expectEqual(a.hash(), a.hash());
    try std.testing.expect(a.hash() != b.hash());
}
