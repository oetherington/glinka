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
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const Allocator = std.mem.Allocator;
const WriteContext = @import("../../common/writer.zig").WriteContext;

pub const Type = union(This.Type) {
    const This = @This();

    pub const Ptr = *const This;

    pub const TupleType = @import("tuple_type.zig");
    pub const ArrayType = @import("array_type.zig").ArrayType;
    pub const ClassType = @import("class_type.zig");
    pub const EnumType = @import("enum_type.zig");
    pub const FunctionType = @import("function_type.zig").FunctionType;
    pub const UnionType = @import("union_type.zig").UnionType;
    pub const AliasType = @import("alias_type.zig").AliasType;
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
        Object,
        Tuple,
        Array,
        Class,
        Enum,
        Function,
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
    Object,
    Tuple: TupleType,
    Array: ArrayType,
    Class: ClassType,
    Enum: EnumType,
    Function: FunctionType,
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

    pub fn newObject() This {
        return This{ .Object = {} };
    }

    pub fn newArray(arr: ArrayType) This {
        return This{ .Array = arr };
    }

    pub fn newFunction(func: FunctionType) This {
        return This{ .Function = func };
    }

    pub fn newUnion(un: UnionType) This {
        return This{ .Union = un };
    }

    pub fn newAlias(alias: AliasType) This {
        return This{ .Alias = alias };
    }

    pub fn isAssignableTo(self: This.Ptr, target: This.Ptr) bool {
        if (self.getType() == .Undefined)
            return true;

        if (target.getType() == .Any)
            return true;

        if (self == target)
            return true;

        switch (self.*) {
            .Array => |arr| {
                if (target.getType() != .Array)
                    return false;

                if (arr.subtype.getType() == .Unknown)
                    return true;

                return arr.subtype.isAssignableTo(target.Array.subtype);
            },
            .Union => |un| {
                for (un.tys) |ty|
                    if (!ty.isAssignableTo(target))
                        return false;
                return true;
            },
            .Alias => |al| return al.ty.isAssignableTo(target),
            else => {},
        }

        switch (target.*) {
            .Union => |un| {
                for (un.tys) |ty|
                    if (self.isAssignableTo(ty))
                        return true;
            },
            .Alias => |al| return self.isAssignableTo(al.ty),
            else => {},
        }

        return false;
    }

    pub fn write(self: This, writer: anytype) anyerror!void {
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
            .Object => try writer.print("object", .{}),
            .Tuple => try writer.print("tuple", .{}),
            .Array => |arr| try arr.write(writer),
            .Class => try writer.print("class", .{}),
            .Enum => try writer.print("enum", .{}),
            .Function => |func| try func.write(writer),
            .Union => |un| try un.write(writer),
            .Alias => |al| try al.write(writer),
            .Interface => try writer.print("interface", .{}),
        }
    }

    pub fn dump(self: This) void {
        const writer = std.io.getStdOut().writer();
        self.write(writer) catch unreachable;
        writer.print("\n", .{}) catch unreachable;
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

test "can create an object type" {
    const ty = Type.newObject();
    try expectEqual(Type.Type.Object, ty.getType());
}

test "can create an array type" {
    const sub = Type.newBoolean();
    const ty = Type.newArray(Type.ArrayType{ .subtype = &sub });
    try expectEqual(Type.Type.Array, ty.getType());
    try expectEqual(Type.Type.Boolean, ty.Array.subtype.getType());
}

test "can create a union type" {
    const str = Type.newString();
    const num = Type.newNumber();
    const ty = Type.newUnion(Type.UnionType{
        .tys = &[_]Type.Ptr{ &str, &num },
    });
    try expectEqual(Type.Type.Union, ty.getType());
    try expectEqual(@intCast(usize, 2), ty.Union.tys.len);
    try expectEqual(Type.Type.String, ty.Union.tys[0].getType());
    try expectEqual(Type.Type.Number, ty.Union.tys[1].getType());
}

test "can create a function type" {
    const str = Type.newString();
    const num = Type.newNumber();
    const ty = Type.newFunction(Type.FunctionType{
        .ret = &str,
        .args = &[_]Type.Ptr{ &str, &num },
    });
    try expectEqual(Type.Type.Function, ty.getType());
    try expectEqual(Type.Type.String, ty.Function.ret.getType());
    try expectEqual(@intCast(usize, 2), ty.Function.args.len);
    try expectEqual(Type.Type.String, ty.Function.args[0].getType());
    try expectEqual(Type.Type.Number, ty.Function.args[1].getType());
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

test "undefined is assignable to all other types" {
    const n = Type.newNumber();
    const a = Type.newAny();
    const b = Type.newBoolean();
    const v = Type.newVoid();
    const s = Type.newString();
    const u = Type.newUndefined();

    try AssignableTestCase.new(&u, &n).run();
    try AssignableTestCase.new(&u, &a).run();
    try AssignableTestCase.new(&u, &b).run();
    try AssignableTestCase.new(&u, &v).run();
    try AssignableTestCase.new(&u, &s).run();
}

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

test "unions can be assigned from any of their subtypes" {
    const n = Type.newNumber();
    const b = Type.newBoolean();
    const s = Type.newString();

    const u = Type.newUnion(Type.UnionType{
        .tys = &[_]Type.Ptr{ &n, &b },
    });

    try AssignableTestCase.new(&n, &u).run();
    try AssignableTestCase.new(&b, &u).run();
    try AssignableTestCase.newF(&s, &u).run();
}

test "array subtypes must match for assignment" {
    const n = Type.newNumber();
    const b = Type.newBoolean();
    const na = Type.newArray(Type.ArrayType{ .subtype = &n });
    const ba = Type.newArray(Type.ArrayType{ .subtype = &b });

    try AssignableTestCase.new(&na, &na).run();
    try AssignableTestCase.new(&ba, &ba).run();
    try AssignableTestCase.newF(&na, &ba).run();
}

test "unknown[] can be assigned to any array type" {
    const n = Type.newNumber();
    const b = Type.newBoolean();
    const u = Type.newUnknown();
    const na = Type.newArray(Type.ArrayType{ .subtype = &n });
    const ba = Type.newArray(Type.ArrayType{ .subtype = &b });
    const ua = Type.newArray(Type.ArrayType{ .subtype = &u });

    try AssignableTestCase.new(&ua, &na).run();
    try AssignableTestCase.new(&ua, &ba).run();
    try AssignableTestCase.newF(&na, &ua).run();
}

test "aliases and their subtypes are interchangeable in assignments" {
    const n = Type.newNumber();
    const b = Type.newBoolean();
    const na = Type.newAlias(Type.AliasType{ .name = "a", .ty = &n });

    try AssignableTestCase.new(&n, &na).run();
    try AssignableTestCase.new(&na, &n).run();
    try AssignableTestCase.newF(&b, &na).run();
    try AssignableTestCase.newF(&na, &b).run();
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

const WriteTypeTestCase = struct {
    ty: Type,
    expected: []const u8,

    pub fn run(self: WriteTypeTestCase) !void {
        const ctx = try WriteContext(.{}).new(std.testing.allocator);
        defer ctx.deinit();

        try self.ty.write(ctx.writer());

        const str = try ctx.toString();
        defer ctx.freeString(str);

        try expectEqualStrings(self.expected, str);
    }
};

test "can write an unknown type" {
    try (WriteTypeTestCase{
        .ty = Type.newUnknown(),
        .expected = "unknown",
    }).run();
}

test "can write an any type" {
    try (WriteTypeTestCase{
        .ty = Type.newAny(),
        .expected = "any",
    }).run();
}

test "can write a void type" {
    try (WriteTypeTestCase{
        .ty = Type.newVoid(),
        .expected = "void",
    }).run();
}

test "can write a null type" {
    try (WriteTypeTestCase{
        .ty = Type.newNull(),
        .expected = "null",
    }).run();
}

test "can write an undefined type" {
    try (WriteTypeTestCase{
        .ty = Type.newUndefined(),
        .expected = "undefined",
    }).run();
}

test "can write a never type" {
    try (WriteTypeTestCase{
        .ty = Type.newNever(),
        .expected = "never",
    }).run();
}

test "can write a number type" {
    try (WriteTypeTestCase{
        .ty = Type.newNumber(),
        .expected = "number",
    }).run();
}

test "can write a string type" {
    try (WriteTypeTestCase{
        .ty = Type.newString(),
        .expected = "string",
    }).run();
}

test "can write a boolean type" {
    try (WriteTypeTestCase{
        .ty = Type.newBoolean(),
        .expected = "boolean",
    }).run();
}

test "can write an object type" {
    try (WriteTypeTestCase{
        .ty = Type.newObject(),
        .expected = "object",
    }).run();
}

// TODO: Add test for writing a tuple type

test "can write an array type" {
    const n = Type.newNumber();
    try (WriteTypeTestCase{
        .ty = Type.newArray(Type.ArrayType{ .subtype = &n }),
        .expected = "number[]",
    }).run();
}

test "can write a nested array type" {
    const n = Type.newNumber();
    const s = Type.newString();
    const u = Type.newUnion(Type.UnionType{ .tys = &[_]Type.Ptr{ &n, &s } });
    try (WriteTypeTestCase{
        .ty = Type.newArray(Type.ArrayType{ .subtype = &u }),
        .expected = "(number|string)[]",
    }).run();
}

// TODO: Add test for writing a class type

// TODO: Add test for writing an enum type

test "can write a function type" {
    const n = Type.newNumber();
    const s = Type.newString();
    try (WriteTypeTestCase{
        .ty = Type.newFunction(Type.FunctionType{
            .ret = &n,
            .args = &[_]Type.Ptr{ &n, &s },
        }),
        .expected = "function(number, string) : number",
    }).run();
}

test "can write a union type" {
    const n = Type.newNumber();
    const s = Type.newString();
    try (WriteTypeTestCase{
        .ty = Type.newUnion(Type.UnionType{ .tys = &[_]Type.Ptr{ &n, &s } }),
        .expected = "number|string",
    }).run();
}

test "can write a union type" {
    const n = Type.newNumber();
    try (WriteTypeTestCase{
        .ty = Type.newAlias(Type.AliasType{ .name = "AnAlias", .ty = &n }),
        .expected = "AnAlias (an alias for number)",
    }).run();
}

// TODO: Add test for writing an interface type
