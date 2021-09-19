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
const expectEqualStrings = std.testing.expectEqualStrings;
const Type = @import("types/type.zig").Type;
const TypeError = @import("types/type_error.zig").TypeError;
const implicitAnyError = @import("types/implicit_any_error.zig");
const ImplicitAnyError = implicitAnyError.ImplicitAnyError;
const OpError = @import("op_error.zig").OpError;
const ParseError = @import("../frontend/parse_result.zig").ParseError;
const Parser = @import("../frontend/parser.zig").Parser;
const TokenType = @import("../common/token.zig").Token.Type;
const Cursor = @import("../common/cursor.zig").Cursor;

pub const CompileError = union(CompileError.Type) {
    pub const Type = enum(u8) {
        TypeError,
        OpError,
        ImplicitAnyError,
        ParseError,
    };

    TypeError: TypeError,
    OpError: OpError,
    ImplicitAnyError: ImplicitAnyError,
    ParseError: ParseError,

    pub fn typeError(err: TypeError) CompileError {
        return CompileError{
            .TypeError = err,
        };
    }

    pub fn opError(err: OpError) CompileError {
        return CompileError{
            .OpError = err,
        };
    }

    pub fn implicitAnyError(err: ImplicitAnyError) CompileError {
        return CompileError{
            .ImplicitAnyError = err,
        };
    }

    pub fn parseError(err: ParseError) CompileError {
        return CompileError{
            .ParseError = err,
        };
    }

    pub fn getType(self: CompileError) CompileError.Type {
        return @as(CompileError.Type, self);
    }

    pub fn report(self: CompileError, writer: anytype) !void {
        switch (self) {
            .TypeError => |err| try err.report(writer),
            .OpError => |err| try err.report(writer),
            .ImplicitAnyError => |err| try err.report(writer),
            .ParseError => |err| try err.report(writer),
        }
    }
};

test "can create a CompileError from a TypeError" {
    const cursor = Cursor.new(5, 7);
    const valueTy = Type.newString();
    const targetTy = Type.newBoolean();
    const typeError = TypeError.new(cursor, &valueTy, &targetTy);
    const compileError = CompileError.typeError(typeError);
    try expectEqual(CompileError.Type.TypeError, compileError.getType());
    try expectEqual(cursor, compileError.TypeError.csr);
    try expectEqual(&valueTy, compileError.TypeError.valueTy);
    try expectEqual(&targetTy, compileError.TypeError.targetTy);
}

test "can create a CompileError from an OpError" {
    const cursor = Cursor.new(5, 7);
    const op = TokenType.Sub;
    const ty = Type.newString();
    const opError = OpError.new(cursor, op, &ty);
    const compileError = CompileError.opError(opError);
    try expectEqual(CompileError.Type.OpError, compileError.getType());
    // TODO
    // try expectEqual(cursor, compileError.TypeError.csr);
    // try expectEqual(&valueTy, compileError.TypeError.valueTy);
    // try expectEqual(&targetTy, compileError.TypeError.targetTy);
}

test "can create a CompileError from an ImplicitAnyError" {
    const cursor = Cursor.new(2, 5);
    const symbol = "anySymbol";
    const err = ImplicitAnyError.new(cursor, symbol);
    const compileError = CompileError.implicitAnyError(err);
    try expectEqual(CompileError.Type.ImplicitAnyError, compileError.getType());
    try expectEqual(cursor, compileError.ImplicitAnyError.csr);
    try expectEqualStrings(symbol, compileError.ImplicitAnyError.symbol);
}

test "can create a CompileError from a ParseError" {
    const cursor = Cursor.new(3, 5);
    const message = "Some error message";
    const parseError = ParseError.message(cursor, message);
    const compileError = CompileError.parseError(parseError);
    try expectEqual(CompileError.Type.ParseError, compileError.getType());
    try expectEqual(cursor, compileError.ParseError.csr);
    try expectEqualStrings(message, compileError.ParseError.data.Message);
}
