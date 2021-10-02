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
const Cursor = @import("../../common/cursor.zig").Cursor;

pub const ImplicitAnyError = struct {
    csr: Cursor,
    symbol: []const u8,

    pub fn new(csr: Cursor, symbol: []const u8) ImplicitAnyError {
        return ImplicitAnyError{
            .csr = csr,
            .symbol = symbol,
        };
    }

    pub fn report(self: ImplicitAnyError, writer: anytype) !void {
        try writer.print(
            "Error: {d}:{d}: Untyped symbol '{s}' implicitely has type 'any'\n",
            .{
                self.csr.ln,
                self.csr.ch,
                self.symbol,
            },
        );
    }
};

test "can initialize an ImplicitAnyError" {
    const csr = Cursor.new(2, 5);
    const symbol = "anySymbol";
    const err = ImplicitAnyError.new(csr, symbol);
    try expectEqual(csr, err.csr);
    try expectEqualStrings(symbol, err.symbol);
}
