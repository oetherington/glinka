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
const expectEqual = std.testing.expectEqual;
const Cursor = @import("../../common/cursor.zig").Cursor;
const Type = @import("../../common/types/type.zig").Type;

pub const ReturnError = struct {
    csr: Cursor,
    expectedTy: Type.Ptr,
    actualTy: ?Type.Ptr,

    pub fn new(
        csr: Cursor,
        expectedTy: Type.Ptr,
        actualTy: ?Type.Ptr,
    ) ReturnError {
        return ReturnError{
            .csr = csr,
            .expectedTy = expectedTy,
            .actualTy = actualTy,
        };
    }

    pub fn report(self: ReturnError, writer: anytype) !void {
        if (self.expectedTy.getType() == .Void) {
            try writer.print(
                "Error: {d}:{d}: Cannot return a value from a void function",
                .{ self.csr.ln, self.csr.ch },
            );
        } else if (self.actualTy) |actualTy| {
            try writer.print(
                "Error: {d}:{d}: Cannot return a value of type ",
                .{ self.csr.ln, self.csr.ch },
            );
            try actualTy.write(writer);
            try writer.print(" from a function returning ", .{});
            try self.expectedTy.write(writer);
        } else {
            try writer.print(
                "Error: {d}:{d}: Non-void function must return value of type ",
                .{ self.csr.ln, self.csr.ch },
            );
            try self.expectedTy.write(writer);
        }

        try writer.print("\n", .{});
    }
};

test "can initialize a ReturnError" {
    const csr = Cursor.new(2, 5);
    const expectedTy = Type.newNumber();
    const actualTy = Type.newString();
    const err = ReturnError.new(csr, &expectedTy, &actualTy);
    try expectEqual(csr, err.csr);
    try expectEqual(&expectedTy, err.expectedTy);
    try expectEqual(&actualTy, err.actualTy.?);
}
