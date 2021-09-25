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

pub const GenericError = struct {
    csr: Cursor,
    msg: []const u8,

    pub fn new(csr: Cursor, msg: []const u8) GenericError {
        return GenericError{
            .csr = csr,
            .msg = msg,
        };
    }

    pub fn report(self: GenericError, writer: anytype) !void {
        try writer.print(
            "Error: {d}:{d}: {s}\n",
            .{
                self.csr.ln,
                self.csr.ch,
                self.msg,
            },
        );
    }
};

test "can initialize a GenericError" {
    const csr = Cursor.new(2, 5);
    const msg = "Some error message";
    const err = GenericError.new(csr, msg);
    try expectEqual(csr, err.csr);
    try expectEqualStrings(msg, err.msg);
}
