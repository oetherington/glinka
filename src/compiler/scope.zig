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

    const Map = std.StringHashMap(Symbol);

    parent: ?*Scope,
    map: Map,
    ctx: ?Context = null,

    pub fn new(alloc: Allocator, parent: ?*Scope) *Scope {
        var self = alloc.create(Scope) catch allocate.reportAndExit();
        self.parent = parent;
        self.map = Map.init(alloc);
        return self;
    }

    pub fn deinit(self: *Scope) void {
        const alloc = self.getAllocator();
        self.map.deinit();
        alloc.destroy(self);
    }

    pub fn getAllocator(self: *Scope) Allocator {
        return self.map.allocator;
    }

    pub fn put(
        self: *Scope,
        name: []const u8,
        ty: Type.Ptr,
        isConst: bool,
        csr: Cursor,
    ) void {
        std.debug.assert(self.getLocal(name) == null);

        self.map.putNoClobber(
            name,
            Symbol.new(ty, isConst, csr),
        ) catch allocate.reportAndExit();
    }

    pub fn get(self: *Scope, name: []const u8) ?Symbol {
        const res = self.map.get(name);
        if (res) |ty|
            return ty;
        if (self.parent) |parent|
            return parent.get(name);
        return null;
    }

    pub fn getLocal(self: *Scope, name: []const u8) ?Symbol {
        return self.map.get(name);
    }

    pub fn isInContext(self: *Scope, ctx: Context) bool {
        // TODO: self.ctx == ctx seems to crash the zig compiler
        if (self.ctx != null and self.ctx.? == ctx)
            return true;
        if (self.parent) |parent|
            return parent.isInContext(ctx);
        return false;
    }
};

test "can insert into and retrieve from scope" {
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
    if (res) |symbol| {
        try expectEqual(ty, symbol.ty);
        try expectEqual(isConst, symbol.isConst);
        try expectEqual(csr, symbol.csr);
    }
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

test "scope returns null for undefined symbols" {
    var scope = Scope.new(std.testing.allocator, null);
    defer scope.deinit();
    const res = scope.get("anUndefinedSymbol");
    try expect(res == null);
}

test "can retrieve from scope recursively" {
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
    if (res) |symbol| {
        try expectEqual(ty, symbol.ty);
        try expectEqual(isConst, symbol.isConst);
        try expectEqual(csr, symbol.csr);
    }
}
