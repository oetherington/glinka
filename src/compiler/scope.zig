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
const TypeBook = @import("typebook.zig").TypeBook;
const Type = @import("../common/types/type.zig").Type;
const Cursor = @import("../common/cursor.zig").Cursor;
const allocate = @import("../common/allocate.zig");

pub const Scope = struct {
    pub const Context = enum {
        Loop,
        Try,
        Catch,
        Finally,
        Switch,
        Function,
        ArrowFunction,
    };

    pub const Symbol = struct {
        ty: Type.Ptr,
        isConst: bool,
        csr: Cursor,

        pub fn new(ty: Type.Ptr, isConst: bool, csr: Cursor) Symbol {
            return Symbol{
                .ty = ty,
                .isConst = isConst,
                .csr = csr,
            };
        }
    };

    const TypeMap = std.StringHashMap(Type.Ptr);
    const SymbolMap = std.StringHashMap(Symbol);

    parent: ?*Scope,
    typeMap: TypeMap,
    symbolMap: SymbolMap,
    ctx: ?Context,

    pub fn new(alloc: Allocator, parent: ?*Scope) *Scope {
        var self = alloc.create(Scope) catch allocate.reportAndExit();
        self.parent = parent;
        self.typeMap = TypeMap.init(alloc);
        self.symbolMap = SymbolMap.init(alloc);
        self.ctx = null;
        return self;
    }

    pub fn deinit(self: *Scope) void {
        const alloc = self.getAllocator();
        self.symbolMap.deinit();
        self.typeMap.deinit();
        alloc.destroy(self);
    }

    pub fn getAllocator(self: *Scope) Allocator {
        return self.symbolMap.allocator;
    }

    pub fn put(
        self: *Scope,
        name: []const u8,
        ty: Type.Ptr,
        isConst: bool,
        csr: Cursor,
    ) void {
        // It is the caller's responsibility to ensure the symbol doesn't exist
        std.debug.assert(self.getLocal(name) == null);

        self.symbolMap.putNoClobber(
            name,
            Symbol.new(ty, isConst, csr),
        ) catch allocate.reportAndExit();
    }

    pub fn get(self: *Scope, name: []const u8) ?Symbol {
        const res = self.symbolMap.get(name);
        if (res) |ty|
            return ty;
        if (self.parent) |parent|
            return parent.get(name);
        return null;
    }

    pub fn getLocal(self: *Scope, name: []const u8) ?Symbol {
        return self.symbolMap.get(name);
    }

    pub fn putType(self: *Scope, name: []const u8, ty: Type.Ptr) void {
        // It is the caller's responsibility to ensure the type doesn't exist
        std.debug.assert(self.getTypeLocal(name) == null);

        self.typeMap.putNoClobber(name, ty) catch allocate.reportAndExit();
    }

    pub fn getType(self: *Scope, name: []const u8) ?Type.Ptr {
        const res = self.typeMap.get(name);
        if (res) |ty|
            return ty;
        if (self.parent) |parent|
            return parent.getType(name);
        return null;
    }

    pub fn getTypeLocal(self: *Scope, name: []const u8) ?Type.Ptr {
        return self.typeMap.get(name);
    }

    pub fn isInContext(self: *Scope, ctx: Context) bool {
        // TODO: self.ctx == ctx seems to crash the zig compiler
        if (self.ctx != null and self.ctx.? == ctx)
            return true;
        if (self.parent) |parent|
            return parent.isInContext(ctx);
        return false;
    }

    fn dumpInternal(self: *Scope, indent: usize) void {
        var iter = self.symbolMap.iterator();
        while (iter.next()) |sym| {
            var i: usize = 0;
            while (i < indent) : (i += 1) {
                std.debug.print(" ", .{});
            }

            std.debug.print("{s}: ", .{sym.key_ptr.*});
            sym.value_ptr.ty.dump();
        }

        if (self.parent) |parent|
            parent.dumpInternal(indent + 2);
    }

    pub fn dump(self: *Scope) void {
        self.dumpInternal(0);
    }
};

test "can insert symbols into and retrieve symbols from scope" {
    var scope = Scope.new(std.testing.allocator, null);
    defer scope.deinit();

    var typebook = TypeBook.new(std.testing.allocator);
    defer typebook.deinit();

    const name = "aVariable";
    const ty = typebook.getBoolean();
    const isConst = true;
    const csr = Cursor.new(2, 9);
    scope.put(name, ty, isConst, csr);

    const res = scope.get(name);
    try expect(res != null);
    try expectEqual(ty, res.?.ty);
    try expectEqual(isConst, res.?.isConst);
    try expectEqual(csr, res.?.csr);
}

test "scope returns null for undefined symbols" {
    var scope = Scope.new(std.testing.allocator, null);
    defer scope.deinit();
    const res = scope.get("anUndefinedSymbol");
    try expect(res == null);
}

test "can retrieve symbols from scope recursively" {
    var scope = Scope.new(std.testing.allocator, null);
    defer scope.deinit();

    var typebook = TypeBook.new(std.testing.allocator);
    defer typebook.deinit();

    const name = "aVariable";
    const ty = typebook.getBoolean();
    const isConst = true;
    const csr = Cursor.new(2, 9);
    scope.put(name, ty, isConst, csr);

    var child = Scope.new(std.testing.allocator, scope);
    defer child.deinit();

    const res = child.get(name);
    try expect(res != null);
    try expectEqual(ty, res.?.ty);
    try expectEqual(isConst, res.?.isConst);
    try expectEqual(csr, res.?.csr);
}

test "can insert types into and retrieve types from scope" {
    var scope = Scope.new(std.testing.allocator, null);
    defer scope.deinit();

    var typebook = TypeBook.new(std.testing.allocator);
    defer typebook.deinit();

    const name = "AnAlias";
    const ty = typebook.getBoolean();
    scope.putType(name, ty);

    const res = scope.getType(name);
    try expect(res != null);
    try expectEqual(ty, res.?);
}

test "scope returns null for undefined types" {
    var scope = Scope.new(std.testing.allocator, null);
    defer scope.deinit();
    const res = scope.getType("AnUndefinedType");
    try expect(res == null);
}

test "can retrieve types from scope recursively" {
    var scope = Scope.new(std.testing.allocator, null);
    defer scope.deinit();

    var typebook = TypeBook.new(std.testing.allocator);
    defer typebook.deinit();

    const name = "AnAlias";
    const ty = typebook.getBoolean();
    scope.putType(name, ty);

    var child = Scope.new(std.testing.allocator, scope);
    defer child.deinit();

    const res = child.getType(name);
    try expect(res != null);
    try expectEqual(ty, res.?);
}

test "scope can retrieve context" {
    var first = Scope.new(std.testing.allocator, null);
    defer first.deinit();

    var second = Scope.new(std.testing.allocator, first);
    defer second.deinit();

    try expect(!second.isInContext(.Loop));

    first.ctx = .Loop;

    try expect(second.isInContext(.Loop));

    first.ctx = null;
    second.ctx = .Loop;

    try expect(second.isInContext(.Loop));
    try expect(!first.isInContext(.Loop));
}
