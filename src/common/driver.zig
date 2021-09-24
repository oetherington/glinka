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
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const Parser = @import("parser.zig").Parser;
const ParseResult = @import("parse_result.zig").ParseResult;

pub fn Driver(comptime ParserImpl: type) type {
    return struct {
        const This = @This();

        pub const ParsedFile = struct {
            code: []u8,
            res: ParseResult,
        };

        pub fn parseFile(
            self: This,
            arena: *Arena,
            path: []const u8,
        ) !ParsedFile {
            _ = self;

            const cwd = std.fs.cwd();

            const code = try cwd.readFileAlloc(
                &arena.allocator,
                path,
                std.math.maxInt(usize),
            );

            var parserImpl = ParserImpl.new(arena, code);
            var parser = parserImpl.getParser();

            var res = try parser.getAst(arena);

            return ParsedFile{
                .code = code,
                .res = res,
            };
        }
    };
}
