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
const Type = @import("types/type.zig").Type;
const TypeBook = @import("types/typebook.zig").TypeBook;
const Cursor = @import("../common/cursor.zig").Cursor;
const allocate = @import("../common/allocate.zig");

pub const Scope = struct {
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

    pub fn new(alloc: *Allocator, parent: ?*Scope) *Scope {
        var self = alloc.create(Scope) catch allocate.reportAndExit();
        self.parent = parent;
        self.map = Map.init(alloc);
        return self;
    }

    pub fn deinit(self: *Scope) void {
        var alloc = self.map.allocator;
        self.map.deinit();
        alloc.destroy(self);
    }

    pub fn put(
        self: *Scope,
        name: []const u8,
        ty: Type.Ptr,
        isConst: bool,
        csr: Cursor,
    ) error{SymbolAlreadyExists}!void {
        if (self.getLocal(name)) |local| {
            _ = local;
            return error.SymbolAlreadyExists;
        }

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
    try scope.put(name, ty, isConst, csr);

    const res = scope.get(name);
    try expect(res != null);
    if (res) |symbol| {
        try expectEqual(ty, symbol.ty);
        try expectEqual(isConst, symbol.isConst);
        try expectEqual(csr, symbol.csr);
    }
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
    try scope.put(name, ty, isConst, csr);

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
