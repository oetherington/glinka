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
const Cursor = @import("../../common/cursor.zig").Cursor;
const Type = @import("../../common/types/type.zig").Type;
const CompileError = @import("../errors/compile_error.zig").CompileError;

pub const InferResult = union(Variant) {
    pub const Variant = enum {
        Success,
        Error,
    };

    Success: Type.Ptr,
    Error: CompileError,

    pub fn success(ty: Type.Ptr) InferResult {
        return InferResult{
            .Success = ty,
        };
    }

    pub fn err(e: CompileError) InferResult {
        return InferResult{
            .Error = e,
        };
    }

    pub fn getType(self: InferResult) Variant {
        return @as(Variant, self);
    }
};

test "can create a success InferResult" {
    const boolean = Type.newBoolean();
    const ptr = &boolean;
    const result = InferResult.success(ptr);
    try expectEqual(InferResult.Success, result.getType());
    try expectEqual(ptr, result.Success);
}

test "can create an error InferResult" {
    const cursor = Cursor.new(2, 5);
    const symbol = "anySymbol";
    const implicitAnyError = @import("../errors/implicit_any_error.zig");
    const ImplicitAnyError = implicitAnyError.ImplicitAnyError;
    const err = ImplicitAnyError.new(cursor, symbol);
    const compileError = CompileError.implicitAnyError(err);
    const result = InferResult.err(compileError);
    try expectEqual(InferResult.Error, result.getType());
    try expectEqual(CompileError.Type.ImplicitAnyError, result.Error.getType());
    const e = result.Error.ImplicitAnyError;
    try expectEqual(cursor, e.csr);
    try expectEqualStrings(symbol, e.symbol);
}
