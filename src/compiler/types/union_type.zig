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
const Allocator = std.mem.Allocator;
const Type = @import("type.zig").Type;

const MapContext = struct {
    pub fn hash(self: @This(), tys: []Type.Ptr) u64 {
        _ = self;

        var res: u64 = 0;
        for (tys) |ty|
            res ^= @ptrToInt(ty);

        return res;
    }

    pub fn eql(self: @This(), a: []Type.Ptr, b: []Type.Ptr) bool {
        _ = self;
        return std.mem.eql(Type.Ptr, a, b);
    }
};

const UnionTypeMap = struct {
    const Map = std.HashMap(
        []Type.Ptr,
        Type.Ptr,
        MapContext,
        std.hash_map.default_max_load_percentage,
    );

    map: Map,

    pub fn new(alloc: *Allocator) UnionTypeMap {
        return UnionTypeMap{
            .map = Map.init(alloc),
        };
    }

    pub fn deinit(self: *UnionTypeMap) void {
        var it = self.map.valueIterator();
        while (it.next()) |val| {
            const unionTy = val.*.*;
            std.debug.assert(std.meta.activeTag(unionTy) == .Union);
            self.map.allocator.free(unionTy.Union.tys);
            self.map.allocator.destroy(val.*);
        }

        self.map.deinit();
    }

    pub fn get(self: *UnionTypeMap, tys_: []Type.Ptr) !Type.Ptr {
        const Context = struct {
            pub fn lessThan(_: @This(), lhs: Type.Ptr, rhs: Type.Ptr) bool {
                return @ptrToInt(lhs) < @ptrToInt(rhs);
            }
        };

        var tys = try self.map.allocator.alloc(Type.Ptr, tys_.len);
        std.mem.copy(Type.Ptr, tys, tys_);
        std.sort.insertionSort(Type.Ptr, tys, Context{}, Context.lessThan);

        const existing = self.map.get(tys);
        if (existing) |ty| {
            self.map.allocator.free(tys);
            return ty;
        }

        var ty = try self.map.allocator.create(Type);
        ty.* = Type{ .Union = Type.UnionType{ .tys = tys } };
        try self.map.put(tys, ty);
        return ty;
    }
};

pub const UnionType = struct {
    pub const Map = UnionTypeMap;

    tys: []Type.Ptr,

    pub fn contains(self: UnionType, ty: Type.Ptr) bool {
        for (self.tys) |t|
            if (t == ty)
                return true;

        return false;
    }
};
