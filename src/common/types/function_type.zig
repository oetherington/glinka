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

pub const FunctionType = struct {
    ret: Type.Ptr,
    args: []Type.Ptr,

    pub fn new(ret: Type.Ptr, args: []Type.Ptr) FunctionType {
        return FunctionType{
            .ret = ret,
            .args = args,
        };
    }

    pub fn hash(self: FunctionType) usize {
        var result: usize = self.ret.hash() ^ 0xd35558c29b7438aa;

        for (self.args) |arg, index|
            result ^= arg.hash() >> @intCast(u6, index + 1);

        return result;
    }

    pub fn write(self: FunctionType, writer: anytype) !void {
        try writer.print("function(", .{});

        var prefix: []const u8 = "";
        for (self.args) |arg| {
            try writer.print("{s}", .{prefix});
            try arg.write(writer);
            prefix = ", ";
        }

        try writer.print(") : ", .{});

        try self.ret.write(writer);
    }
};

test "can hash a FunctionType" {
    const num = Type.newNumber();
    const str = Type.newString();

    const a = FunctionType.new(&num, &[_]Type.Ptr{&str});
    const b = FunctionType.new(&str, &[_]Type.Ptr{&num});

    try std.testing.expectEqual(a.hash(), a.hash());
    try std.testing.expect(a.hash() != b.hash());
}
