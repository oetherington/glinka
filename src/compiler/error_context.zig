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
const ParseError = @import("../frontend/parse_result.zig").ParseError;
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
};
