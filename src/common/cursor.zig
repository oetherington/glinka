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

const CursorImpl = u32;

pub const Cursor = struct {
    ln: CursorImpl,
    ch: CursorImpl,

    pub fn new(ln: CursorImpl, ch: CursorImpl) Cursor {
        return Cursor{
            .ln = ln,
            .ch = ch,
        };
    }

    pub fn eql(a: Cursor, b: Cursor) bool {
        return a.ln == b.ln and a.ch == b.ch;
    }
};

test "cursor can be initialized" {
    const ln: CursorImpl = 4;
    const ch: CursorImpl = 7;

    const c = Cursor.new(ln, ch);

    try expectEqual(ln, c.ln);
    try expectEqual(ch, c.ch);
}
