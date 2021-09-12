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
const Backend = @import("backends/backend.zig").Backend;
const JsBackend = @import("backends/js/js_backend.zig").JsBackend;
const Compiler = @import("compiler/compiler.zig").Compiler;

pub fn main() !void {
    std.io.getStdOut().writeAll("Glinka - version 0.0.1\n") catch unreachable;

    const code: []const u8 = "var test: number = true;";

    var alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = alloc.deinit();

    var parser = Parser.new(&alloc.allocator, code);
    defer parser.deinit();

    var backend = try JsBackend.new(&alloc.allocator);
    defer backend.deinit();

    var compiler = Compiler.new(&alloc.allocator, &parser, &backend.backend);
    defer compiler.deinit();

    try compiler.run();

    if (compiler.hasErrors()) {
        try compiler.reportErrors();
    } else {
        var res = try backend.toString();
        defer backend.freeString(res);
        std.log.info("Result: {s}", .{res});
    }
}
