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
const Type = @import("../../common/types/type.zig").Type;

pub const InferContext = struct {
    pub const Variant = enum {
        None,
        New,
        Class,
    };

    pub const Data = union(Variant) {
        None: void,
        New: void,
        Class: Type.Ptr,
    };

    parent: ?*const InferContext,
    data: Data,

    pub fn none(parent: ?*const InferContext) InferContext {
        return InferContext{
            .parent = parent,
            .data = Data{ .None = {} },
        };
    }

    pub fn new(parent: ?*const InferContext) InferContext {
        return InferContext{
            .parent = parent,
            .data = Data{ .New = {} },
        };
    }

    pub fn class(parent: ?*const InferContext, ty: Type.Ptr) InferContext {
        return InferContext{
            .parent = parent,
            .data = Data{ .Class = ty },
        };
    }

    pub fn getType(self: InferContext) Variant {
        return @as(Variant, self.data);
    }

    pub fn isConstructible(self: InferContext) bool {
        return self.getType() == .New;
    }
};

test "can create a 'None' InferContext" {
    const ctx = InferContext.none(null);
    try std.testing.expectEqual(InferContext.Variant.None, ctx.getType());
}

test "can create a 'New' InferContext" {
    const ctx = InferContext.new(null);
    try std.testing.expectEqual(InferContext.Variant.New, ctx.getType());
}

test "can create a 'Class' InferContext" {
    const num = Type.newNumber();
    const ctx = InferContext.class(null, &num);
    try std.testing.expectEqual(InferContext.Variant.Class, ctx.getType());
    try std.testing.expectEqual(&num, ctx.data.Class);
}

test "only 'New' InferContext is constructible" {
    const newCtx = InferContext.new(null);
    const noneCtx = InferContext.none(null);
    const childCtx = InferContext.none(&newCtx);
    try std.testing.expect(newCtx.isConstructible());
    try std.testing.expect(!noneCtx.isConstructible());
    try std.testing.expect(!childCtx.isConstructible());
}
