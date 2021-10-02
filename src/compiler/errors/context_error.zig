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
const TokenType = @import("../../common/token.zig").Token.Type;
const Type = @import("../../common/types/type.zig").Type;

pub const ContextError = struct {
    csr: Cursor,
    found: []const u8,
    expectedContext: []const u8,

    pub fn new(
        csr: Cursor,
        found: []const u8,
        expectedContext: []const u8,
    ) ContextError {
        return ContextError{
            .csr = csr,
            .found = found,
            .expectedContext = expectedContext,
        };
    }

    pub fn report(self: ContextError, writer: anytype) !void {
        try writer.print(
            "Error: {d}:{d}: {s} cannot occur outside of {s}\n",
            .{
                self.csr.ln,
                self.csr.ch,
                self.found,
                self.expectedContext,
            },
        );
    }
};

test "can initialize a ContextError" {
    const csr = Cursor.new(2, 5);
    const found = "Something";
    const expectedContext = "a context";
    const err = ContextError.new(csr, found, expectedContext);
    try expectEqual(csr, err.csr);
    try expectEqualStrings(found, err.found);
    try expectEqualStrings(expectedContext, err.expectedContext);
}
