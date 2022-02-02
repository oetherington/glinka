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
const Visibility = @import("../../common/node.zig").Visibility;

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

    fn hasProtectedAccessTo(self: InferContext, ty: Type.Ptr) bool {
        if (self.getType() == .Class and
            (self.data.Class == ty or self.data.Class.Class.isSubclassOf(ty)))
            return true;

        if (self.parent) |parent|
            return parent.hasProtectedAccessTo(ty);

        return false;
    }

    fn hasPrivateAccessTo(self: InferContext, ty: Type.Ptr) bool {
        if (self.getType() == .Class and self.data.Class == ty)
            return true;

        if (self.parent) |parent|
            return parent.hasPrivateAccessTo(ty);

        return false;
    }

    pub fn hasAccessTo(self: InferContext, ty: Type.Ptr, vis: Visibility) bool {
        return switch (vis) {
            .Public => true,
            .Protected => self.hasProtectedAccessTo(ty),
            .Private => self.hasPrivateAccessTo(ty),
        };
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

test "all contexts can access public members" {
    const c0 = Type.newClass(
        Type.ClassType.new(null, "A", &[_]Type.ClassType.Member{}),
    );
    const ctx = InferContext.none(null);
    try std.testing.expect(ctx.hasAccessTo(&c0, .Public));
}

test "the local class and subclasses can access protected members" {
    const c0 = Type.newClass(
        Type.ClassType.new(null, "A", &[_]Type.ClassType.Member{}),
    );
    const c1 = Type.newClass(
        Type.ClassType.new(&c0, "B", &[_]Type.ClassType.Member{}),
    );

    const ctx0 = InferContext.class(null, &c0);
    try std.testing.expect(ctx0.hasAccessTo(&c0, .Protected));

    const ctx1 = InferContext.class(null, &c1);
    try std.testing.expect(ctx1.hasAccessTo(&c0, .Protected));
    try std.testing.expect(ctx1.hasAccessTo(&c1, .Protected));

    const ctx2 = InferContext.class(&ctx0, &c1);
    try std.testing.expect(ctx2.hasAccessTo(&c0, .Protected));
    try std.testing.expect(ctx2.hasAccessTo(&c1, .Protected));

    const ctx3 = InferContext.none(null);
    try std.testing.expect(!ctx3.hasAccessTo(&c0, .Protected));
    try std.testing.expect(!ctx3.hasAccessTo(&c1, .Protected));
}

test "only the local class can access private members" {
    const c0 = Type.newClass(
        Type.ClassType.new(null, "A", &[_]Type.ClassType.Member{}),
    );
    const c1 = Type.newClass(
        Type.ClassType.new(&c0, "B", &[_]Type.ClassType.Member{}),
    );

    const ctx0 = InferContext.class(null, &c0);
    try std.testing.expect(ctx0.hasAccessTo(&c0, .Private));

    const ctx1 = InferContext.class(null, &c1);
    try std.testing.expect(!ctx1.hasAccessTo(&c0, .Private));
    try std.testing.expect(ctx1.hasAccessTo(&c1, .Private));

    const ctx2 = InferContext.class(&ctx0, &c1);
    try std.testing.expect(ctx2.hasAccessTo(&c0, .Private));
    try std.testing.expect(ctx2.hasAccessTo(&c1, .Private));

    const ctx3 = InferContext.none(null);
    try std.testing.expect(!ctx3.hasAccessTo(&c0, .Private));
    try std.testing.expect(!ctx3.hasAccessTo(&c1, .Private));
}
