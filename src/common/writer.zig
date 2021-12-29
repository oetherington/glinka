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
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const Allocator = std.mem.Allocator;

pub const WriteContextOpts = struct {
    pageSize: usize = 4096,
};

pub fn WriteContext(comptime opts: WriteContextOpts) type {
    return struct {
        const This = @This();
        pub const Writer = std.io.Writer(*This, Error, This.write);
        const Error = anyerror;
        const PageList = std.ArrayList([]u8);
        const pageSize = opts.pageSize;

        alloc: Allocator,
        list: PageList,

        pub fn new(alloc: Allocator) !*This {
            // We allocate this on the heap as we need a stable pointer to
            // create the std.io.Writer instance
            var self = try alloc.create(This);
            self.alloc = alloc;
            self.list = PageList.init(alloc);
            try self.allocNewPage();
            return self;
        }

        pub fn deinit(self: *This) void {
            for (self.list.items) |*page| {
                page.len = pageSize;
                self.alloc.free(page.*);
            }
            self.list.deinit();
            self.alloc.destroy(self);
        }

        pub fn getPageSize(self: This) usize {
            _ = self;
            return pageSize;
        }

        pub fn toString(self: This) ![]u8 {
            var bytes: usize = 0;
            for (self.list.items) |page|
                bytes += page.len;

            var str = try self.alloc.alloc(u8, bytes);

            bytes = 0;
            for (self.list.items) |page| {
                std.mem.copy(u8, str[bytes..], page);
                bytes += page.len;
            }

            return str;
        }

        pub fn freeString(self: This, str: []u8) void {
            self.alloc.free(str);
        }

        pub fn writer(self: *This) Writer {
            return Writer{
                .context = self,
            };
        }

        fn write(self: *This, bytes: []const u8) Error!usize {
            std.debug.assert(self.list.items.len > 0);

            if (bytes.len > pageSize) {
                var written: usize = 0;
                while (written < bytes.len) {
                    const end = std.math.min(written + pageSize, bytes.len);
                    written += try self.write(bytes[written..end]);
                }
            } else {
                @setRuntimeSafety(false);

                var idx = self.list.items.len - 1;
                var cur = self.list.items[idx];
                if (cur.len + bytes.len < pageSize) {
                    const end = cur.len + bytes.len;
                    std.mem.copy(u8, cur[cur.len..end], bytes);
                    self.list.items[idx].len += bytes.len;
                } else {
                    const toWrite = pageSize - cur.len;
                    std.mem.copy(
                        u8,
                        cur[cur.len..pageSize],
                        bytes[0..toWrite],
                    );
                    self.list.items[idx].len = pageSize;

                    try self.allocNewPage();
                    idx = self.list.items.len - 1;
                    cur = self.list.items[idx];

                    const len = bytes.len - toWrite;
                    std.mem.copy(u8, cur[0..len], bytes[toWrite..]);
                    self.list.items[idx].len = len;
                }
            }

            return bytes.len;
        }

        fn allocNewPage(self: *This) !void {
            var page = try self.alloc.alloc(u8, pageSize);
            page.len = 0;
            try self.list.append(page);
        }
    };
}

test "can write to Writer" {
    var writeCtx = try WriteContext(.{}).new(std.testing.allocator);
    defer writeCtx.deinit();
    try expectEqual(@intCast(usize, 4096), writeCtx.getPageSize());

    var writer = writeCtx.writer();
    try writer.print("hello world", .{});

    var str = try writeCtx.toString();
    defer writeCtx.freeString(str);
    try expectEqualStrings("hello world", str);
}

test "can write to Writer across a page boundary" {
    var writeCtx = try WriteContext(.{
        .pageSize = 8,
    }).new(std.testing.allocator);
    defer writeCtx.deinit();
    try expectEqual(@intCast(usize, 8), writeCtx.getPageSize());

    var writer = writeCtx.writer();
    try writer.print("hello", .{});
    try writer.print(" world", .{});

    var str = try writeCtx.toString();
    defer writeCtx.freeString(str);
    try expectEqualStrings("hello world", str);
}

test "can write to Writer with a string larger than the page size" {
    var writeCtx = try WriteContext(.{
        .pageSize = 4,
    }).new(std.testing.allocator);
    defer writeCtx.deinit();
    try expectEqual(@intCast(usize, 4), writeCtx.getPageSize());

    var writer = writeCtx.writer();
    try writer.print("hello world", .{});

    var str = try writeCtx.toString();
    defer writeCtx.freeString(str);
    try expectEqualStrings("hello world", str);
}
