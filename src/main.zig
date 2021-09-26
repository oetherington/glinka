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
const version = @import("version.zig").version;
const TsParser = @import("frontend/ts_parser.zig").TsParser;
const Parser = @import("common/parser.zig").Parser;
const Backend = @import("common/backend.zig").Backend;
const JsBackend = @import("backends/js/js_backend.zig").JsBackend;
const Compiler = @import("compiler/compiler.zig").Compiler;
const Config = @import("common/config.zig").Config;
const Driver = @import("common/driver.zig").Driver;

pub fn main() !void {
    try std.io.getStdOut().writer().print(
        "Glinka - version {d}.{d}.{d}{s}{s}\n",
        .{
            version.major,
            version.minor,
            version.patch,
            if (version.pre) |pre| "-" ++ pre else "",
            if (version.build) |build| "-" ++ build else "",
        },
    );

    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = allocator.deinit();
    var alloc = &allocator.allocator;

    const config = Config{};

    const driver = Driver(TsParser){};

    var backend = try JsBackend.new(alloc);
    defer backend.deinit();

    var compiler = Compiler.new(alloc, &config, &backend.backend);
    defer compiler.deinit();

    const path = "examples/example_1.ts";

    try compiler.compile(driver, path);

    if (compiler.hasErrors()) {
        try compiler.reportErrors();
    } else {
        var res = try backend.toString();
        defer backend.freeString(res);
        std.log.info("Result: {s}", .{res});
    }
}
