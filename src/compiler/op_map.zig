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
const Type = @import("../common/types/type.zig").Type;
const TokenType = @import("../common/token.zig").Token.Type;
const TypeBook = @import("./typebook.zig").TypeBook;

pub const OpEntry = union(Variant) {
    const Variant = enum {
        Unary,
        Binary,
    };

    // When output is null, the output type is the same as the input type
    Unary: struct {
        input: Type.Ptr,
        output: ?Type.Ptr,
    },
    Binary: struct {
        input: Type.Ptr,
        output: ?Type.Ptr,
    },

    pub fn un(input: Type.Ptr, output: ?Type.Ptr) OpEntry {
        return OpEntry{
            .Unary = .{
                .input = input,
                .output = output,
            },
        };
    }

    pub fn bin(input: Type.Ptr, output: ?Type.Ptr) OpEntry {
        return OpEntry{
            .Binary = .{
                .input = input,
                .output = output,
            },
        };
    }
};

pub const OpMap = [std.meta.fields(TokenType).len]?OpEntry;

pub fn populateOpMap(b: *TypeBook) void {
    std.mem.set(?OpEntry, b.opMap[0..], null);

    const h = (struct {
        book: *TypeBook,

        fn put(self: @This(), op: TokenType, entry: OpEntry) void {
            self.book.opMap[@enumToInt(op)] = entry;
        }
    }){ .book = b };

    h.put(.Inc, OpEntry.un(&b.numberTy, null));
    h.put(.Dec, OpEntry.un(&b.numberTy, null));
    h.put(.BitNot, OpEntry.un(&b.numberTy, null));

    h.put(.LogicalNot, OpEntry.un(&b.anyTy, &b.booleanTy));

    h.put(.Delete, OpEntry.un(&b.anyTy, &b.booleanTy));

    h.put(.Nullish, OpEntry.un(&b.anyTy, &b.anyTy)); // TODO: Fix output

    h.put(.Assign, OpEntry.bin(&b.anyTy, null));
    h.put(.NullishAssign, OpEntry.bin(&b.anyTy, &b.anyTy)); // TODO: Fix output

    h.put(
        .Add,
        OpEntry.bin(b.getUnion(&.{ &b.numberTy, &b.stringTy }), null),
    );
    h.put(
        .AddAssign,
        OpEntry.bin(b.getUnion(&.{ &b.numberTy, &b.stringTy }), null),
    );

    h.put(.Sub, OpEntry.bin(&b.numberTy, null));
    h.put(.Mul, OpEntry.bin(&b.numberTy, null));
    h.put(.Pow, OpEntry.bin(&b.numberTy, null));
    h.put(.Div, OpEntry.bin(&b.numberTy, null));
    h.put(.Mod, OpEntry.bin(&b.numberTy, null));
    h.put(.SubAssign, OpEntry.bin(&b.numberTy, null));
    h.put(.MulAssign, OpEntry.bin(&b.numberTy, null));
    h.put(.DivAssign, OpEntry.bin(&b.numberTy, null));
    h.put(.ModAssign, OpEntry.bin(&b.numberTy, null));
    h.put(.PowAssign, OpEntry.bin(&b.numberTy, null));
    h.put(.BitAndAssign, OpEntry.bin(&b.numberTy, null));
    h.put(.BitOrAssign, OpEntry.bin(&b.numberTy, null));
    h.put(.BitNotAssign, OpEntry.bin(&b.numberTy, null));
    h.put(.BitXorAssign, OpEntry.bin(&b.numberTy, null));
    h.put(.ShiftRightAssign, OpEntry.bin(&b.numberTy, null));
    h.put(.ShiftRightUnsignedAssign, OpEntry.bin(&b.numberTy, null));
    h.put(.ShiftLeftAssign, OpEntry.bin(&b.numberTy, null));
    h.put(.BitAnd, OpEntry.bin(&b.numberTy, null));
    h.put(.BitOr, OpEntry.bin(&b.numberTy, null));
    h.put(.BitXor, OpEntry.bin(&b.numberTy, null));
    h.put(.ShiftRight, OpEntry.bin(&b.numberTy, null));
    h.put(.ShiftRightUnsigned, OpEntry.bin(&b.numberTy, null));
    h.put(.ShiftLeft, OpEntry.bin(&b.numberTy, null));

    h.put(.CmpGreater, OpEntry.bin(&b.numberTy, &b.booleanTy));
    h.put(.CmpGreaterEq, OpEntry.bin(&b.numberTy, &b.booleanTy));
    h.put(.CmpLess, OpEntry.bin(&b.numberTy, &b.booleanTy));
    h.put(.CmpLessEq, OpEntry.bin(&b.numberTy, &b.booleanTy));

    h.put(.CmpEq, OpEntry.bin(&b.anyTy, &b.booleanTy));
    h.put(.CmpStrictEq, OpEntry.bin(&b.anyTy, &b.booleanTy));
    h.put(.CmpNotEq, OpEntry.bin(&b.anyTy, &b.booleanTy));
    h.put(.CmpStrictNotEq, OpEntry.bin(&b.anyTy, &b.booleanTy));
    h.put(.LogicalAnd, OpEntry.bin(&b.anyTy, &b.booleanTy));
    h.put(.LogicalOr, OpEntry.bin(&b.anyTy, &b.booleanTy));
    h.put(.LogicalAndAssign, OpEntry.bin(&b.anyTy, &b.booleanTy));
    h.put(.LogicalOrAssign, OpEntry.bin(&b.anyTy, &b.booleanTy));
}
