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
const expectEqualStrings = std.testing.expectEqualStrings;
const Cursor = @import("../common/cursor.zig").Cursor;
const TokenType = @import("../common/token.zig").Token.Type;
const Type = @import("types/type.zig").Type;

pub const OpError = struct {
    csr: Cursor,
    op: TokenType,
    ty: Type.Ptr,

    pub fn new(csr: Cursor, op: TokenType, ty: Type.Ptr) OpError {
        return OpError{
            .csr = csr,
            .op = op,
            .ty = ty,
        };
    }

    pub fn report(self: OpError, writer: anytype) !void {
        try writer.print(
            "Error: {d}:{d}: Operator '{s}' is not defined for type '",
            .{
                self.csr.ln,
                self.csr.ch,
                @tagName(self.op),
            },
        );
        try self.ty.write(writer);
        try writer.print("'\n", .{});
    }
};

test "can initialize an OpError" {
    const csr = Cursor.new(2, 5);
    const op = TokenType.Sub;
    const ty = Type.newString();
    const err = OpError.new(csr, op, &ty);
    try expectEqual(csr, err.csr);
    try expectEqual(op, err.op);
    try expectEqual(&ty, err.ty);
}
