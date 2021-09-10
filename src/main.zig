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
const Parser = @import("frontend/parser.zig").Parser;

pub fn main() !void {
    std.io.getStdOut().writeAll("Glinka - version 0.0.1\n") catch unreachable;

    var alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = alloc.deinit();

    const code: []const u8 = "var test: number = abc;";

    var parser = Parser.new(&alloc.allocator, code);
    defer parser.deinit();

    const res = try parser.next();
    _ = res;

    switch (res) {
        .Success => |node| node.dump(),
        .Error => |err| try err.report(),
        .NoMatch => std.log.info("NoMatch", .{}),
    }
}
