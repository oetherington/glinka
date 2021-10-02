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
const TokenType = @import("../../common/token.zig").Token.Type;
const Type = @import("../../common/types/type.zig").Type;

pub const AssignError = struct {
    csr: Cursor,
    left: Type.Ptr,
    right: Type.Ptr,

    pub fn new(csr: Cursor, left: Type.Ptr, right: Type.Ptr) AssignError {
        return AssignError{
            .csr = csr,
            .left = left,
            .right = right,
        };
    }

    pub fn report(self: AssignError, writer: anytype) !void {
        try writer.print(
            "Error: {d}:{d}: Value of type '",
            .{ self.csr.ln, self.csr.ch },
        );
        try self.right.write(writer);
        try writer.print("' cannot be assigned to a variable of type '", .{});
        try self.left.write(writer);
        try writer.print("'\n", .{});
    }
};

test "can initialize an AssignError" {
    const csr = Cursor.new(2, 5);
    const left = Type.newString();
    const right = Type.newNumber();
    const err = AssignError.new(csr, &left, &right);
    try expectEqual(csr, err.csr);
    try expectEqual(&left, err.left);
    try expectEqual(&right, err.right);
}
