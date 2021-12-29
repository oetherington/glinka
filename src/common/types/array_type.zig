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
const Allocator = std.mem.Allocator;
const Type = @import("type.zig").Type;
const allocate = @import("../../common/allocate.zig");

const MapContext = struct {
    pub fn hash(self: @This(), arr: ArrayType) u64 {
        _ = self;
        return @ptrToInt(arr.subtype);
    }

    pub fn eql(self: @This(), a: ArrayType, b: ArrayType) bool {
        _ = self;
        return a.subtype == b.subtype;
    }
};

const ArrayTypeMap = struct {
    const Map = std.HashMap(
        ArrayType,
        Type.Ptr,
        MapContext,
        std.hash_map.default_max_load_percentage,
    );

    map: Map,

    pub fn new(alloc: Allocator) ArrayTypeMap {
        return ArrayTypeMap{
            .map = Map.init(alloc),
        };
    }

    pub fn deinit(self: *ArrayTypeMap) void {
        var it = self.map.valueIterator();

        while (it.next()) |val|
            self.map.allocator.destroy(val.*);

        self.map.deinit();
    }

    pub fn get(self: *ArrayTypeMap, subtype: Type.Ptr) Type.Ptr {
        const arrTy = ArrayType{ .subtype = subtype };

        if (self.map.get(arrTy)) |ty|
            return ty;

        var ty = allocate.create(self.map.allocator, Type);
        ty.* = Type{ .Array = arrTy };
        self.map.put(arrTy, ty) catch allocate.reportAndExit();
        return ty;
    }
};

pub const ArrayType = struct {
    pub const Map = ArrayTypeMap;

    subtype: Type.Ptr,

    pub fn write(self: ArrayType, writer: anytype) !void {
        if (self.subtype.getType() == .Union) {
            try writer.print("(", .{});
            try self.subtype.write(writer);
            try writer.print(")[]", .{});
        } else {
            try self.subtype.write(writer);
            try writer.print("[]", .{});
        }
    }
};
