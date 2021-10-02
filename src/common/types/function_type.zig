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
const allocate = @import("../../common/allocate.zig");

const MapContext = struct {
    pub fn hash(self: @This(), ty: FunctionType) u64 {
        _ = self;

        var res: u64 = @ptrToInt(ty.ret);
        for (ty.args) |arg|
            res ^= @ptrToInt(arg);

        return res;
    }

    pub fn eql(self: @This(), a: FunctionType, b: FunctionType) bool {
        _ = self;
        return a.ret == b.ret and std.mem.eql(Type.Ptr, a.args, b.args);
    }
};

const FunctionTypeMap = struct {
    const Map = std.HashMap(
        FunctionType,
        Type.Ptr,
        MapContext,
        std.hash_map.default_max_load_percentage,
    );

    map: Map,

    pub fn new(alloc: *Allocator) FunctionTypeMap {
        return FunctionTypeMap{
            .map = Map.init(alloc),
        };
    }

    pub fn deinit(self: *FunctionTypeMap) void {
        var it = self.map.valueIterator();

        while (it.next()) |val| {
            const funcTy = val.*.*;
            std.debug.assert(std.meta.activeTag(funcTy) == .Function);
            self.map.allocator.free(funcTy.Function.args);
            self.map.allocator.destroy(val.*);
        }

        self.map.deinit();
    }

    pub fn get(
        self: *FunctionTypeMap,
        ret: Type.Ptr,
        args: []Type.Ptr,
    ) Type.Ptr {
        var funcTy = FunctionType{
            .ret = ret,
            .args = args,
        };

        const existing = self.map.get(funcTy);
        if (existing) |ty|
            return ty;

        funcTy.args = allocate.alloc(self.map.allocator, Type.Ptr, args.len);
        std.mem.copy(Type.Ptr, funcTy.args, args);

        var ty = allocate.create(self.map.allocator, Type);
        ty.* = Type{ .Function = funcTy };
        self.map.put(funcTy, ty) catch allocate.reportAndExit();
        return ty;
    }
};

pub const FunctionType = struct {
    pub const Map = FunctionTypeMap;

    ret: Type.Ptr,
    args: []Type.Ptr,

    pub fn write(self: FunctionType, writer: anytype) !void {
        try writer.print("function(", .{});

        var prefix: []const u8 = "";
        for (self.args) |arg| {
            try writer.print("{s}", .{prefix});
            try arg.write(writer);
            prefix = ", ";
        }

        try writer.print(") : ", .{});

        try self.ret.write(writer);
    }
};
