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
const expectEqualSlices = std.testing.expectEqualSlices;
const ParseError = @import("../frontend/parse_result.zig").ParseError;
const Parser = @import("../frontend/parser.zig").Parser;
const Cursor = @import("../common/cursor.zig").Cursor;

pub const CompileErrorType = enum(u8) {
    ParseError,
};

pub const CompileError = union(CompileErrorType) {
    ParseError: ParseError,

    pub fn parseError(err: ParseError) CompileError {
        return CompileError{
            .ParseError = err,
        };
    }

    pub fn getType(self: CompileError) CompileErrorType {
        return @as(CompileErrorType, self);
    }

    pub fn report(self: CompileError, writer: anytype) !void {
        switch (self) {
            .ParseError => |err| try err.report(writer),
        }
    }
};

test "can create a CompilerError from a ParseError" {
    const cursor = Cursor.new(3, 5);
    const message = "Some error message";
    const parseError = ParseError.message(cursor, message);
    const compileError = CompileError.parseError(parseError);
    try expectEqual(CompileErrorType.ParseError, compileError.getType());
    try expectEqual(cursor, compileError.ParseError.csr);
    try expectEqualSlices(u8, message, compileError.ParseError.data.Message);
}
