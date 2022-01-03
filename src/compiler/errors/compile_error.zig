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
const Type = @import("../../common/types/type.zig").Type;
const TypeError = @import("type_error.zig").TypeError;
const implicitAnyError = @import("implicit_any_error.zig");
const ImplicitAnyError = implicitAnyError.ImplicitAnyError;
const OpError = @import("op_error.zig").OpError;
const ContextError = @import("context_error.zig").ContextError;
const RedefinitionError = @import("redefinition_error.zig").RedefinitionError;
const GenericError = @import("generic_error.zig").GenericError;
const AssignError = @import("assign_error.zig").AssignError;
const ReturnError = @import("return_error.zig").ReturnError;
const ParseError = @import("../../common/parse_error.zig").ParseError;
const TokenType = @import("../../common/token.zig").Token.Type;
const Cursor = @import("../../common/cursor.zig").Cursor;
const reportTestCase = @import("report_test_case.zig").reportTestCase;

pub const CompileError = union(CompileError.Type) {
    pub const Type = enum(u8) {
        TypeError,
        OpError,
        ContextError,
        RedefinitionError,
        GenericError,
        AssignError,
        ReturnError,
        ImplicitAnyError,
        ParseError,
    };

    TypeError: TypeError,
    OpError: OpError,
    ContextError: ContextError,
    RedefinitionError: RedefinitionError,
    GenericError: GenericError,
    AssignError: AssignError,
    ReturnError: ReturnError,
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

    pub fn contextError(err: ContextError) CompileError {
        return CompileError{
            .ContextError = err,
        };
    }

    pub fn redefinitionError(err: RedefinitionError) CompileError {
        return CompileError{
            .RedefinitionError = err,
        };
    }

    pub fn genericError(err: GenericError) CompileError {
        return CompileError{
            .GenericError = err,
        };
    }

    pub fn assignError(err: AssignError) CompileError {
        return CompileError{
            .AssignError = err,
        };
    }

    pub fn returnError(err: ReturnError) CompileError {
        return CompileError{
            .ReturnError = err,
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
            .ContextError => |err| try err.report(writer),
            .RedefinitionError => |err| try err.report(writer),
            .GenericError => |err| try err.report(writer),
            .AssignError => |err| try err.report(writer),
            .ReturnError => |err| try err.report(writer),
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
    try reportTestCase(
        compileError,
        "Type Error: 5:7: The type string is not coercable to the type boolean\n",
    );
}

test "can create a CompileError from an OpError" {
    const cursor = Cursor.new(5, 7);
    const op = TokenType.Sub;
    const ty = Type.newString();
    const opError = OpError.new(cursor, op, &ty);
    const compileError = CompileError.opError(opError);
    try expectEqual(CompileError.Type.OpError, compileError.getType());
    try expectEqual(cursor, compileError.OpError.csr);
    try expectEqual(op, compileError.OpError.op);
    try expectEqual(ty.getType(), compileError.OpError.ty.getType());
    try reportTestCase(
        compileError,
        "Error: 5:7: Operator 'Sub' is not defined for type 'string'\n",
    );
}

test "can create a CompileError from a ContextError" {
    const cursor = Cursor.new(5, 7);
    const found = "Something";
    const expectedContext = "a context";
    const ctxError = ContextError.new(cursor, found, expectedContext);
    const compileError = CompileError.contextError(ctxError);
    try expectEqual(CompileError.Type.ContextError, compileError.getType());
    try expectEqual(cursor, compileError.ContextError.csr);
    try expectEqualStrings(found, compileError.ContextError.found);
    try expectEqualStrings(
        expectedContext,
        compileError.ContextError.expectedContext,
    );
    try reportTestCase(
        compileError,
        "Error: 5:7: Something cannot occur outside of a context\n",
    );
}

test "can create a CompileError from a RedefinitionError" {
    const name = "aSymbol";
    const firstDefined = Cursor.new(1, 1);
    const secondDefined = Cursor.new(3, 3);
    const redefError = RedefinitionError.new(name, firstDefined, secondDefined);
    const compileError = CompileError.redefinitionError(redefError);
    try expectEqual(CompileError.Type.RedefinitionError, compileError.getType());
    try expectEqualStrings(name, compileError.RedefinitionError.name);
    try expectEqual(firstDefined, compileError.RedefinitionError.firstDefined);
    try expectEqual(secondDefined, compileError.RedefinitionError.secondDefined);
    try reportTestCase(
        compileError,
        "Error: 3:3: Redefinition of symbol 'aSymbol' (first defined at line 1)\n",
    );
}

test "can create a CompileError from a GenericError" {
    const csr = Cursor.new(3, 3);
    const msg = "Some error message";
    const genError = GenericError.new(csr, msg);
    const compileError = CompileError.genericError(genError);
    try expectEqual(CompileError.Type.GenericError, compileError.getType());
    try expectEqual(csr, compileError.GenericError.csr);
    try expectEqualStrings(msg, compileError.GenericError.msg);
    try reportTestCase(compileError, "Error: 3:3: Some error message\n");
}

test "can create a CompileError from an AssignError" {
    const csr = Cursor.new(2, 5);
    const left = Type.newString();
    const right = Type.newNumber();
    const assignErr = AssignError.new(csr, &left, &right);
    const compileError = CompileError.assignError(assignErr);
    try expectEqual(CompileError.Type.AssignError, compileError.getType());
    try expectEqual(csr, compileError.AssignError.csr);
    try expectEqual(&left, compileError.AssignError.left);
    try expectEqual(&right, compileError.AssignError.right);
    try reportTestCase(
        compileError,
        "Error: 2:5: Value of type number cannot be assigned to a variable of type string\n",
    );
}

test "can create a CompileError from a ReturnError" {
    const csr = Cursor.new(2, 5);
    const expectedTy = Type.newNumber();
    const actualTy = Type.newString();
    const returnErr = ReturnError.new(csr, &expectedTy, &actualTy);
    const compileError = CompileError.returnError(returnErr);
    try expectEqual(CompileError.Type.ReturnError, compileError.getType());
    try expectEqual(csr, compileError.ReturnError.csr);
    try expectEqual(&expectedTy, compileError.ReturnError.expectedTy);
    try expectEqual(&actualTy, compileError.ReturnError.actualTy.?);
    try reportTestCase(
        compileError,
        "Error: 2:5: Cannot return a value of type string from a function returning number\n",
    );
}

test "can create a CompileError from an ImplicitAnyError" {
    const cursor = Cursor.new(2, 5);
    const symbol = "anySymbol";
    const err = ImplicitAnyError.new(cursor, symbol);
    const compileError = CompileError.implicitAnyError(err);
    try expectEqual(CompileError.Type.ImplicitAnyError, compileError.getType());
    try expectEqual(cursor, compileError.ImplicitAnyError.csr);
    try expectEqualStrings(symbol, compileError.ImplicitAnyError.symbol);
    try reportTestCase(
        compileError,
        "Error: 2:5: Untyped symbol 'anySymbol' implicitely has type 'any'\n",
    );
}

test "can create a CompileError from a ParseError" {
    const cursor = Cursor.new(3, 5);
    const message = "Some error message";
    const parseError = ParseError.message(cursor, message);
    const compileError = CompileError.parseError(parseError);
    try expectEqual(CompileError.Type.ParseError, compileError.getType());
    try expectEqual(cursor, compileError.ParseError.csr);
    try expectEqualStrings(message, compileError.ParseError.data.Message);
    // TODO: Add test for reporting ParseErrors
}
