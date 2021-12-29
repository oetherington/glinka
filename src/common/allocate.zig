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
const Allocator = std.mem.Allocator;

pub fn create(a: *Allocator, comptime T: type) *T {
    return a.create(T) catch reportAndExit();
}

pub fn alloc(a: *Allocator, comptime T: type, n: usize) []T {
    return a.alloc(T, n) catch reportAndExit();
}

pub fn reportAndExit() noreturn {
    const stderr = std.io.getStdOut().writer();
    stderr.print("*** Out of memory ***\n", .{}) catch unreachable;
    std.debug.dumpCurrentStackTrace(null);
    std.process.exit(1);
}
