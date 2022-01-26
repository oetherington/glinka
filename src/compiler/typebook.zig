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
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const Allocator = std.mem.Allocator;
const Type = @import("../common/types/type.zig").Type;
const TokenType = @import("../common/token.zig").Token.Type;
const allocate = @import("../common/allocate.zig");
const opMap = @import("./op_map.zig");

pub const TypeBook = struct {
    const TypeMap = std.HashMap(
        Type,
        Type.Ptr,
        struct {
            pub fn hash(self: @This(), value: Type) u64 {
                _ = self;
                return value.hash();
            }

            pub fn eql(self: @This(), a: Type, b: Type) bool {
                _ = self;
                return a.eql(&b);
            }
        },
        std.hash_map.default_max_load_percentage,
    );

    const TypeList = std.ArrayList(Type.Ptr);

    alloc: Allocator,
    opMap: opMap.OpMap,
    unknownTy: Type = Type.newUnknown(),
    anyTy: Type = Type.newAny(),
    voidTy: Type = Type.newVoid(),
    nullTy: Type = Type.newNull(),
    undefinedTy: Type = Type.newUndefined(),
    neverTy: Type = Type.newNever(),
    numberTy: Type = Type.newNumber(),
    stringTy: Type = Type.newString(),
    booleanTy: Type = Type.newBoolean(),
    objectTy: Type = Type.newObject(),
    tyMap: TypeMap,

    pub fn new(alloc: Allocator) *TypeBook {
        var self = alloc.create(TypeBook) catch allocate.reportAndExit();
        self.* = TypeBook{
            .alloc = alloc,
            .opMap = undefined,
            .tyMap = TypeMap.init(alloc),
        };
        opMap.populateOpMap(self);
        return self;
    }

    pub fn deinit(self: *TypeBook) void {
        var it = self.tyMap.valueIterator();

        while (it.next()) |val| {
            switch (val.*.*) {
                .Function => |f| self.alloc.free(f.args),
                .Union => |un| self.alloc.free(un.tys),
                .Interface => |in| self.alloc.free(in.members),
                .Class => |cls| self.alloc.free(cls.members),
                else => {},
            }

            self.alloc.destroy(val.*);
        }

        self.tyMap.deinit();

        self.alloc.destroy(self);
    }

    pub fn combine(self: *TypeBook, a: Type.Ptr, b: Type.Ptr) Type.Ptr {
        if (b.isAssignableTo(a))
            return a;
        return self.getUnion(&[_]Type.Ptr{ a, b });
    }

    pub fn getOpEntry(self: *TypeBook, ty: TokenType) ?opMap.OpEntry {
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

    pub fn getObject(self: *TypeBook) Type.Ptr {
        return &self.objectTy;
    }

    pub fn getArray(self: *TypeBook, subtype: Type.Ptr) Type.Ptr {
        const arr = Type{ .Array = Type.ArrayType{ .subtype = subtype } };

        if (self.tyMap.get(arr)) |ty|
            return ty;

        var ty = allocate.create(self.alloc, Type);
        ty.* = arr;
        self.tyMap.put(arr, ty) catch allocate.reportAndExit();
        return ty;
    }

    pub fn getFunction(
        self: *TypeBook,
        ret: Type.Ptr,
        args: []Type.Ptr,
    ) Type.Ptr {
        var funcTy = Type{
            .Function = Type.FunctionType{
                .ret = ret,
                .args = args,
            },
        };

        if (self.tyMap.get(funcTy)) |ty|
            return ty;

        funcTy.Function.args = allocate.alloc(self.alloc, Type.Ptr, args.len);
        std.mem.copy(Type.Ptr, funcTy.Function.args, args);

        var ty = allocate.create(self.alloc, Type);
        ty.* = funcTy;
        self.tyMap.put(funcTy, ty) catch allocate.reportAndExit();
        return ty;
    }

    fn flattenUnionTypes(out: *TypeList, in: []Type.Ptr) void {
        for (in) |ty| {
            switch (ty.*) {
                .Union => |un| TypeBook.flattenUnionTypes(out, un.tys),
                else => out.append(ty) catch allocate.reportAndExit(),
            }
        }
    }

    pub fn getUnion(self: *TypeBook, tys_: []Type.Ptr) Type.Ptr {
        const Context = struct {
            pub fn lessThan(_: @This(), lhs: Type.Ptr, rhs: Type.Ptr) bool {
                return @ptrToInt(lhs) < @ptrToInt(rhs);
            }
        };

        // TODO: Refactor this to avoid allocating
        var flattened = TypeList.init(self.alloc);
        flattened.ensureTotalCapacity(tys_.len) catch allocate.reportAndExit();
        TypeBook.flattenUnionTypes(&flattened, tys_);

        const tys = flattened.items;
        std.sort.insertionSort(Type.Ptr, tys, Context{}, Context.lessThan);

        const un = Type{ .Union = Type.UnionType{ .tys = tys } };

        const existing = self.tyMap.get(un);
        if (existing) |ty| {
            flattened.deinit();
            return ty;
        }

        var ty = allocate.create(self.alloc, Type);
        ty.* = un;
        self.tyMap.put(un, ty) catch allocate.reportAndExit();
        return ty;
    }

    pub fn putAlias(self: *TypeBook, aliasTy: Type.Ptr) void {
        std.debug.assert(aliasTy.getType() == .Alias);
        self.tyMap.put(aliasTy.*, aliasTy) catch allocate.reportAndExit();
    }

    pub fn getAlias(self: *TypeBook, name: []const u8, ty: Type.Ptr) Type.Ptr {
        const alias = Type{ .Alias = Type.AliasType.new(name, ty) };
        if (self.tyMap.get(alias)) |t|
            return t;
        std.debug.panic("Alias '{s}' has not been prepared", .{name});
    }

    pub fn putInterface(self: *TypeBook, inTy: Type.Ptr) void {
        std.debug.assert(inTy.getType() == .Interface);
        self.tyMap.put(inTy.*, inTy) catch allocate.reportAndExit();
    }

    pub fn getInterface(
        self: *TypeBook,
        members: []Type.InterfaceType.Member,
    ) Type.Ptr {
        var inTy = Type{ .Interface = Type.InterfaceType.new(members) };

        if (self.tyMap.get(inTy)) |ty|
            return ty;

        inTy.Interface.members = allocate.alloc(
            self.alloc,
            Type.InterfaceType.Member,
            members.len,
        );
        std.mem.copy(
            Type.InterfaceType.Member,
            inTy.Interface.members,
            members,
        );

        var ty = allocate.create(self.alloc, Type);
        ty.* = inTy;
        self.tyMap.put(inTy, ty) catch allocate.reportAndExit();
        return ty;
    }

    pub fn putClass(self: *TypeBook, clsTy: Type.Ptr) void {
        std.debug.assert(clsTy.getType() == .Class);
        self.tyMap.put(clsTy.*, clsTy) catch allocate.reportAndExit();
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
    try expectEqual(Type.Type.Object, book.getObject().getType());
}

test "type book can create and retrieve array types" {
    var book = TypeBook.new(std.testing.allocator);
    defer book.deinit();

    const num: *const Type = &book.numberTy;
    const str: *const Type = &book.stringTy;

    const numArray = book.getArray(num);
    try expectEqual(Type.Type.Array, numArray.getType());
    try expectEqual(num, numArray.Array.subtype);

    const numArray2 = book.getArray(num);
    try expectEqual(Type.Type.Array, numArray2.getType());
    try expectEqual(num, numArray2.Array.subtype);
    try expectEqual(numArray, numArray2);

    const strArray = book.getArray(str);
    try expectEqual(Type.Type.Array, strArray.getType());
    try expectEqual(str, strArray.Array.subtype);
    try expect(numArray != strArray);

    const numArrayArray = book.getArray(numArray);
    try expectEqual(Type.Type.Array, numArrayArray.getType());
    try expectEqual(numArray, numArrayArray.Array.subtype);
    try expect(numArray != numArrayArray);
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
    try expect(tys[0] == num and tys[1] == str);

    const numStr2 = book.getUnion(&.{ num, str });
    try expectEqual(numStr, numStr2);

    const strNum = book.getUnion(&.{ str, num });
    try expectEqual(numStr, strNum);

    const boolean = &book.booleanTy;
    const boolNum = book.getUnion(&.{ boolean, num });
    try expect(numStr != boolNum);
}

test "type book can create and retrieve function types" {
    var book = TypeBook.new(std.testing.allocator);
    defer book.deinit();

    const n: *const Type = &book.numberTy;
    const s: *const Type = &book.stringTy;
    const b: *const Type = &book.booleanTy;

    const func = book.getFunction(n, &[_]Type.Ptr{ s, b });

    try expectEqual(Type.Type.Function, func.getType());
    try expectEqual(n, func.Function.ret);
    try expectEqual(@intCast(usize, 2), func.Function.args.len);
    try expectEqual(s, func.Function.args[0]);
    try expectEqual(b, func.Function.args[1]);

    const func2 = book.getFunction(n, &[_]Type.Ptr{ s, b });

    try expectEqual(func, func2);
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

test "typebook can combine types" {
    var book = TypeBook.new(std.testing.allocator);
    defer book.deinit();

    const num = book.getNumber();
    const str = book.getString();

    const a = book.combine(num, num);
    try expectEqual(num, a);

    const b = book.combine(num, str);
    try expectEqual(Type.Type.Union, b.getType());
    try expectEqual(num, b.Union.tys[0]);
    try expectEqual(str, b.Union.tys[1]);
}
