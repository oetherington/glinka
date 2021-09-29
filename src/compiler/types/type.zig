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
const expectEqual = std.testing.expectEqual;
const Allocator = std.mem.Allocator;

pub const Type = union(This.Type) {
    const This = @This();

    pub const Ptr = *const This;

    pub const TupleType = @import("tuple_type.zig");
    pub const ArrayType = @import("array_type.zig");
    pub const ObjectType = @import("object_type.zig");
    pub const EnumType = @import("enum_type.zig");
    pub const FunctionType = @import("function_type.zig");
    pub const OptionalType = @import("optional_type.zig");
    pub const UnionType = @import("union_type.zig").UnionType;
    pub const AliasType = @import("alias_type.zig");
    pub const InterfaceType = @import("interface_type.zig");

    pub const Type = enum {
        Unknown,
        Any,
        Void,
        Null,
        Undefined,
        Never,
        Number,
        String,
        Boolean,
        Tuple,
        Array,
        Object,
        Enum,
        Function,
        Optional,
        Union,
        Alias,
        Interface,
    };

    Unknown,
    Any,
    Void,
    Null,
    Undefined,
    Never,
    Number,
    String,
    Boolean,
    Tuple: TupleType,
    Array: ArrayType,
    Object: ObjectType,
    Enum: EnumType,
    Function: FunctionType,
    Optional: OptionalType,
    Union: UnionType,
    Alias: AliasType,
    Interface: InterfaceType,

    pub fn getType(self: This) This.Type {
        return @as(This.Type, self);
    }

    pub fn newUnknown() This {
        return This{ .Unknown = {} };
    }

    pub fn newAny() This {
        return This{ .Any = {} };
    }

    pub fn newVoid() This {
        return This{ .Void = {} };
    }

    pub fn newNull() This {
        return This{ .Null = {} };
    }

    pub fn newUndefined() This {
        return This{ .Undefined = {} };
    }

    pub fn newNever() This {
        return This{ .Never = {} };
    }

    pub fn newNumber() This {
        return This{ .Number = {} };
    }

    pub fn newString() This {
        return This{ .String = {} };
    }

    pub fn newBoolean() This {
        return This{ .Boolean = {} };
    }

    pub fn newUnion(un: UnionType) This {
        return This{ .Union = un };
    }

    pub fn isAssignableTo(self: This.Ptr, target: This.Ptr) bool {
        if (target.getType() == .Any)
            return true;

        if (self == target)
            return true;

        switch (target.*) {
            .Union => |un| {
                for (un.tys) |ty|
                    if (self.isAssignableTo(ty))
                        return true;
            },
            else => {},
        }

        return false;
    }

    pub fn write(self: This, writer: anytype) !void {
        switch (self) {
            .Unknown => try writer.print("unknown", .{}),
            .Any => try writer.print("any", .{}),
            .Void => try writer.print("void", .{}),
            .Null => try writer.print("null", .{}),
            .Undefined => try writer.print("undefined", .{}),
            .Never => try writer.print("never", .{}),
            .Number => try writer.print("number", .{}),
            .String => try writer.print("string", .{}),
            .Boolean => try writer.print("boolean", .{}),
            .Tuple => try writer.print("tuple", .{}),
            .Array => try writer.print("array", .{}),
            .Object => try writer.print("object", .{}),
            .Enum => try writer.print("enum", .{}),
            .Function => try writer.print("function", .{}),
            .Optional => try writer.print("optional", .{}),
            .Union => try writer.print("union", .{}),
            .Alias => try writer.print("alias", .{}),
            .Interface => try writer.print("interface", .{}),
        }
    }
};

test "can create an unknown type" {
    const ty = Type.newUnknown();
    try expectEqual(Type.Type.Unknown, ty.getType());
}

test "can create an any type" {
    const ty = Type.newAny();
    try expectEqual(Type.Type.Any, ty.getType());
}

test "can create a void type" {
    const ty = Type.newVoid();
    try expectEqual(Type.Type.Void, ty.getType());
}

test "can create a null type" {
    const ty = Type.newNull();
    try expectEqual(Type.Type.Null, ty.getType());
}

test "can create an undefined type" {
    const ty = Type.newUndefined();
    try expectEqual(Type.Type.Undefined, ty.getType());
}

test "can create a never type" {
    const ty = Type.newNever();
    try expectEqual(Type.Type.Never, ty.getType());
}

test "can create a number type" {
    const ty = Type.newNumber();
    try expectEqual(Type.Type.Number, ty.getType());
}

test "can create a string type" {
    const ty = Type.newString();
    try expectEqual(Type.Type.String, ty.getType());
}

test "can create a boolean type" {
    const ty = Type.newBoolean();
    try expectEqual(Type.Type.Boolean, ty.getType());
}

const AssignableTestCase = struct {
    const This = @This();

    fromType: Type.Ptr,
    toType: Type.Ptr,
    isAssignable: bool,

    pub fn new(fromType: Type.Ptr, toType: Type.Ptr) This {
        return This{
            .fromType = fromType,
            .toType = toType,
            .isAssignable = true,
        };
    }

    pub fn newF(fromType: Type.Ptr, toType: Type.Ptr) This {
        return This{
            .fromType = fromType,
            .toType = toType,
            .isAssignable = false,
        };
    }

    pub fn run(self: This) !void {
        try expectEqual(
            self.isAssignable,
            self.fromType.isAssignableTo(self.toType),
        );
    }
};

test "all types are assignable to 'any'" {
    const n = Type.newNumber();
    const a = Type.newAny();
    const b = Type.newBoolean();
    const u = Type.newUnknown();
    const v = Type.newVoid();
    const s = Type.newString();

    try AssignableTestCase.new(&n, &a).run();
    try AssignableTestCase.new(&b, &a).run();
    try AssignableTestCase.new(&a, &a).run();
    try AssignableTestCase.new(&u, &a).run();
    try AssignableTestCase.new(&v, &a).run();
    try AssignableTestCase.new(&s, &a).run();
}

test "types are assignable to themselves" {
    const n = Type.newNumber();
    const a = Type.newAny();
    const b = Type.newBoolean();
    const u = Type.newUnknown();
    const v = Type.newVoid();
    const s = Type.newString();

    try AssignableTestCase.new(&n, &n).run();
    try AssignableTestCase.new(&a, &a).run();
    try AssignableTestCase.new(&b, &b).run();
    try AssignableTestCase.new(&u, &u).run();
    try AssignableTestCase.new(&v, &v).run();
    try AssignableTestCase.new(&s, &s).run();
}

test "other type assignments are invalid" {
    const n = Type.newNumber();
    const a = Type.newAny();
    const b = Type.newBoolean();
    const u = Type.newUnknown();
    const v = Type.newVoid();
    const s = Type.newString();

    try AssignableTestCase.newF(&n, &s).run();
    try AssignableTestCase.newF(&b, &v).run();
    try AssignableTestCase.newF(&a, &u).run();
    try AssignableTestCase.newF(&u, &n).run();
    try AssignableTestCase.newF(&v, &b).run();
}
