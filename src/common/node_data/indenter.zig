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
const expectEqualStrings = std.testing.expectEqualStrings;
const WriteContext = @import("../writer.zig").WriteContext;

pub fn putInd(
    writer: anytype,
    indent: usize,
    comptime fmt: []const u8,
    args: anytype,
) !void {
    var i: usize = 0;
    while (i < indent) : (i += 1) {
        try writer.print(" ", .{});
    }

    try writer.print(fmt, args);
}

test "can format strings with indentation" {
    const ctx = try WriteContext(.{}).new(std.testing.allocator);
    defer ctx.deinit();
    try putInd(ctx.writer(), 0, "hello {s}\n", .{"world"});
    try putInd(ctx.writer(), 4, "hello {s}\n", .{"world"});
    const str = try ctx.toString();
    defer ctx.freeString(str);
    try expectEqualStrings("hello world\n    hello world\n", str);
}
