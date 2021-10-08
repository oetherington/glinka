// glinka
// Copyright (C) 2021 Ollie Etherington
// <www.etherington.xyz>
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
const expectEqual = std.testing.expectEqual;
const Cursor = @import("../../common/cursor.zig").Cursor;
const Type = @import("../../common/types/type.zig").Type;

pub const TypeError = struct {
    csr: Cursor,
    valueTy: Type.Ptr,
    targetTy: Type.Ptr,

    pub fn new(csr: Cursor, valueTy: Type.Ptr, targetTy: Type.Ptr) TypeError {
        return TypeError{
            .csr = csr,
            .valueTy = valueTy,
            .targetTy = targetTy,
        };
    }

    pub fn report(self: TypeError, writer: anytype) !void {
        try writer.print("Type Error: {d}:{d}: The type ", .{
            self.csr.ln,
            self.csr.ch,
        });
        try self.valueTy.write(writer);
        try writer.print(" is not coercable to the type ", .{});
        try self.targetTy.write(writer);
        try writer.print("\n", .{});
    }
};

test "can initialize a TypeError" {
    const csr = Cursor.new(2, 5);
    const valueTy = Type.newNumber();
    const targetTy = Type.newString();
    const err = TypeError.new(csr, &valueTy, &targetTy);
    try expectEqual(csr, err.csr);
    try expectEqual(&valueTy, err.valueTy);
    try expectEqual(&targetTy, err.targetTy);
}
