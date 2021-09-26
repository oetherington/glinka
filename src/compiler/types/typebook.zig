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
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const Allocator = std.mem.Allocator;
const Type = @import("type.zig").Type;
const TokenType = @import("../../common/token.zig").Token.Type;
const allocate = @import("../../common/allocate.zig");

const OpEntry = union(Variant) {
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

const OpMap = [std.meta.fields(TokenType).len]?OpEntry;

fn createOpMap(b: *TypeBook) void {
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

    h.put(.Nullish, OpEntry.un(&b.anyTy, &b.anyTy)); // TODO: Fix output

    h.put(.Assign, OpEntry.bin(&b.anyTy, null));
    h.put(.NullishAssign, OpEntry.bin(&b.anyTy, &b.anyTy)); // TODO Fix output

    h.put(
        .Add,
        OpEntry.bin(b.getUnion(&.{ &b.numberTy, &b.stringTy }), null),
    );

    h.put(.Sub, OpEntry.bin(&b.numberTy, null));
    h.put(.Mul, OpEntry.bin(&b.numberTy, null));
    h.put(.Pow, OpEntry.bin(&b.numberTy, null));
    h.put(.Div, OpEntry.bin(&b.numberTy, null));
    h.put(.Mod, OpEntry.bin(&b.numberTy, null));
    h.put(.AddAssign, OpEntry.bin(&b.numberTy, null));
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

pub const TypeBook = struct {
    alloc: *Allocator,
    opMap: OpMap,
    unknownTy: Type = Type.newUnknown(),
    anyTy: Type = Type.newAny(),
    voidTy: Type = Type.newVoid(),
    nullTy: Type = Type.newNull(),
    undefinedTy: Type = Type.newUndefined(),
    neverTy: Type = Type.newNever(),
    numberTy: Type = Type.newNumber(),
    stringTy: Type = Type.newString(),
    booleanTy: Type = Type.newBoolean(),
    unionTys: Type.UnionType.Map,

    pub fn new(alloc: *Allocator) *TypeBook {
        var self = alloc.create(TypeBook) catch allocate.reportAndExit();
        self.* = TypeBook{
            .alloc = alloc,
            .opMap = undefined,
            .unionTys = Type.UnionType.Map.new(alloc),
        };
        createOpMap(self);
        return self;
    }

    pub fn deinit(self: *TypeBook) void {
        self.unionTys.deinit();
        self.alloc.destroy(self);
    }

    pub fn getOpEntry(self: *TypeBook, ty: TokenType) ?OpEntry {
        return self.opMap[@enumToInt(ty)];
    }

    pub fn getUnknown(self: *TypeBook) Type.Ptr {
        return &self.unknownTy;
    }

    pub fn getAny(self: *TypeBook) Type.Ptr {
        return &self.anyTy;
    }

    pub fn getVoid(self: *TypeBook) Type.Ptr {
        return &self.voidTy;
    }

    pub fn getNull(self: *TypeBook) Type.Ptr {
        return &self.nullTy;
    }

    pub fn getUndefined(self: *TypeBook) Type.Ptr {
        return &self.undefinedTy;
    }

    pub fn getNever(self: *TypeBook) Type.Ptr {
        return &self.neverTy;
    }

    pub fn getNumber(self: *TypeBook) Type.Ptr {
        return &self.numberTy;
    }

    pub fn getString(self: *TypeBook) Type.Ptr {
        return &self.stringTy;
    }

    pub fn getBoolean(self: *TypeBook) Type.Ptr {
        return &self.booleanTy;
    }

    pub fn getUnion(self: *TypeBook, tys: []Type.Ptr) Type.Ptr {
        return self.unionTys.get(tys);
    }
};

test "type book can return builtin types" {
    var book = TypeBook.new(std.testing.allocator);
    defer book.deinit();

    try expectEqual(Type.Type.Unknown, book.getUnknown().getType());
    try expectEqual(Type.Type.Any, book.getAny().getType());
    try expectEqual(Type.Type.Void, book.getVoid().getType());
    try expectEqual(Type.Type.Null, book.getNull().getType());
    try expectEqual(Type.Type.Undefined, book.getUndefined().getType());
    try expectEqual(Type.Type.Never, book.getNever().getType());
    try expectEqual(Type.Type.Number, book.getNumber().getType());
    try expectEqual(Type.Type.String, book.getString().getType());
    try expectEqual(Type.Type.Boolean, book.getBoolean().getType());
}

test "type book can create and retrieve union types" {
    var book = TypeBook.new(std.testing.allocator);
    defer book.deinit();

    const num = &book.numberTy;
    const str = &book.stringTy;
    const numStr = book.getUnion(&.{ num, str });
    try expectEqual(Type.Type.Union, numStr.getType());

    const tys = numStr.Union.tys;
    try expectEqual(@intCast(usize, 2), tys.len);
    try expect((tys[0] == num and tys[1] == str) or (tys[0] == str and tys[1] == num));

    const numStr2 = book.getUnion(&.{ num, str });
    try expectEqual(numStr, numStr2);

    const strNum = book.getUnion(&.{ str, num });
    try expectEqual(numStr, strNum);

    const boolean = &book.booleanTy;
    const boolNum = book.getUnion(&.{ boolean, num });
    try expect(numStr != boolNum);
}

test "type book can return an OpEntry" {
    var book = TypeBook.new(std.testing.allocator);
    defer book.deinit();

    const ty = TokenType.Sub;
    const entry = book.getOpEntry(ty).?;
    try expectEqual(Type.Type.Number, entry.Binary.input.getType());
    try expect(entry.Binary.output == null);
}

test "invalid token types don't have an OpEntry" {
    var book = TypeBook.new(std.testing.allocator);
    defer book.deinit();

    const ty = TokenType.LParen;
    const entry = book.getOpEntry(ty);
    try expect(entry == null);
}
