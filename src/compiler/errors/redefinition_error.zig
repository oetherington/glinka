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

pub const RedefinitionError = struct {
    name: []const u8,
    firstDefined: Cursor,
    secondDefined: Cursor,

    pub fn new(
        name: []const u8,
        firstDefined: Cursor,
        secondDefined: Cursor,
    ) RedefinitionError {
        return RedefinitionError{
            .name = name,
            .firstDefined = firstDefined,
            .secondDefined = secondDefined,
        };
    }

    pub fn report(self: RedefinitionError, writer: anytype) !void {
        try writer.print(
            "Error: {d}:{d}: Redefinition of symbol '{s}' (first defined at line {d})\n",
            .{
                self.secondDefined.ln,
                self.secondDefined.ch,
                self.name,
                self.firstDefined.ln,
            },
        );
    }
};

test "can initialize a RedefinitionError" {
    const name = "aSymbol";
    const firstDefined = Cursor.new(1, 1);
    const secondDefined = Cursor.new(3, 3);
    const err = RedefinitionError.new(name, firstDefined, secondDefined);
    try expectEqualStrings(name, err.name);
    try expectEqual(firstDefined, err.firstDefined);
    try expectEqual(secondDefined, err.secondDefined);
}
