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
const WriteContext = @import("../../common/writer.zig").WriteContext;

pub fn reportTestCase(err: anytype, expectedMessage: []const u8) !void {
    var ctx = try WriteContext(.{}).new(std.testing.allocator);
    defer ctx.deinit();

    try err.report(ctx.writer());

    const report = try ctx.toString();
    defer ctx.freeString(report);

    try expectEqualStrings(expectedMessage, report);
}
