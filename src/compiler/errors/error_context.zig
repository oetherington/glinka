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
const Allocator = std.mem.Allocator;
const Cursor = @import("../../common/cursor.zig").Cursor;
const ParseError = @import("../../common/parse_error.zig").ParseError;
const compileError = @import("compile_error.zig");
const CompileErrorType = compileError.CompileErrorType;
const CompileError = compileError.CompileError;

pub const ErrorContext = struct {
    const ErrorList = std.ArrayList(CompileError);

    list: ErrorList,

    pub fn new(alloc: *Allocator) ErrorContext {
        return ErrorContext{
            .list = ErrorList.init(alloc),
        };
    }

    pub fn deinit(self: *ErrorContext) void {
        self.list.deinit();
    }

    pub fn append(self: *ErrorContext, err: CompileError) !void {
        try self.list.append(err);
    }

    pub fn count(self: ErrorContext) usize {
        return self.list.items.len;
    }

    pub fn get(self: ErrorContext, index: usize) CompileError {
        return self.list.items[index];
    }

    pub fn reportWithWriter(self: ErrorContext, writer: anytype) !void {
        for (self.list.items) |err|
            try err.report(writer);
    }

    pub fn report(self: ErrorContext) !void {
        const writer = std.io.getStdErr().writer();
        try self.reportWithWriter(writer);
    }
};

test "can append errors to an ErrorContext" {
    var ctx = ErrorContext.new(std.testing.allocator);
    defer ctx.deinit();

    const cursor = Cursor.new(3, 5);
    const message = "Some error message";
    const parseError = ParseError.message(cursor, message);
    const err = CompileError.parseError(parseError);

    try expectEqual(@intCast(usize, 0), ctx.count());
    try ctx.append(err);
    try expectEqual(@intCast(usize, 1), ctx.count());
    try expectEqual(err, ctx.get(0));
}
