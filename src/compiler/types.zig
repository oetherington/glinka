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
const Compiler = @import("compiler.zig").Compiler;
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const Type = @import("../common/types/type.zig").Type;
const GenericError = @import("errors/generic_error.zig").GenericError;
const RedefinitionError = @import("errors/redefinition_error.zig").RedefinitionError;
const CompileError = @import("errors/compile_error.zig").CompileError;
const CompilerTestCase = @import("compiler_test_case.zig").CompilerTestCase;
const allocate = @import("../common/allocate.zig");

pub fn hoistAlias(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == NodeType.Alias);

    const alias = nd.data.Alias;
    const name = alias.name;

    if (cmp.scope.getType(name)) |ty| {
        _ = ty;
        cmp.errors.append(CompileError.genericError(
            GenericError.new(nd.csr, cmp.fmt(
                "Redefinition of type {s}",
                .{name},
            )),
        )) catch allocate.reportAndExit();
        return;
    }

    var t = allocate.create(cmp.alloc, Type);
    t.* = Type{ .Alias = Type.AliasType.new(name, Type.hoistedSentinel) };

    cmp.scope.putType(name, t);
}

pub fn processAlias(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == NodeType.Alias);

    const alias = nd.data.Alias;
    const name = alias.name;
    const ty = cmp.findType(alias.value) orelse {
        cmp.errors.append(CompileError.genericError(
            GenericError.new(nd.csr, cmp.fmt(
                "Target type for alias '{s}' cannot be resolved",
                .{name},
            )),
        )) catch allocate.reportAndExit();
        return;
    };

    if (cmp.scope.getTypeMut(name)) |aliasTy| {
        std.debug.assert(aliasTy.getType() == .Alias);
        std.debug.assert(aliasTy.Alias.ty.isHoistedSentinel());
        aliasTy.Alias.ty = ty;
        cmp.typebook.putAlias(aliasTy);
    } else {
        std.debug.panic("Alias type '{s}' has not been prepared!", .{name});
    }
}

test "can compile a type alias declaration" {
    try (CompilerTestCase{
        .code = "type ATypeAlias = number | boolean;",
    }).run();
}

test "aliases don't share scope with variables" {
    try (CompilerTestCase{
        .code = "type AnAlias = number; const AnAlias = 0;",
    }).run();
}

pub fn hoistInterface(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == NodeType.InterfaceType);

    const in = nd.data.InterfaceType;

    const name = if (in.name) |nm|
        nm
    else
        std.debug.panic("Invalid InterfaceType node (has no name)", .{});

    if (cmp.scope.getType(name)) |ty| {
        _ = ty;
        return;
    }

    var ty = allocate.create(cmp.alloc, Type);
    ty.* = Type{
        .Interface = Type.InterfaceType.new(
            &[_]Type.InterfaceType.Member{},
        ),
    };

    cmp.scope.putType(name, ty);
}

pub fn processInterface(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == NodeType.InterfaceType);

    const in = nd.data.InterfaceType;

    const name = if (in.name) |nm|
        nm
    else
        std.debug.panic("Invalid InterfaceType node (has no name)", .{});

    const members = allocate.alloc(
        cmp.alloc,
        Type.InterfaceType.Member,
        in.members.items.len,
    );

    for (in.members.items) |member, index| {
        if (cmp.findType(member.ty)) |ty| {
            members[index] = Type.InterfaceType.Member{
                .name = member.name,
                .ty = ty,
            };
        } else {
            cmp.errors.append(CompileError.genericError(
                GenericError.new(nd.csr, cmp.fmt(
                    "Member '{s}' of interface '{s}' has an invalid type",
                    .{ member.name, name },
                )),
            )) catch allocate.reportAndExit();
            return;
        }
    }

    if (cmp.scope.getTypeMut(name)) |inTy| {
        std.debug.assert(inTy.getType() == .Interface);
        std.debug.assert(inTy.Interface.members.len == 0);
        inTy.Interface.members = members;
        cmp.typebook.putInterface(inTy);
    } else {
        std.debug.panic("Interface type '{s}' has not been prepared!", .{name});
    }
}

test "can compile an interface declaration" {
    try (CompilerTestCase{
        .code = "interface Inter { aString: string; aUnion: number | null; }",
    }).run();
}

test "interfaces don't share scope with variables" {
    try (CompilerTestCase{
        .code = "interface AnInterface { a: number; } const AnInterface = 0;",
    }).run();
}

pub fn hoistClass(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == NodeType.ClassType);

    const clsNd = nd.data.ClassType;
    const name = clsNd.name;

    if (cmp.scope.getType(name)) |ty| {
        _ = ty;
        cmp.errors.append(CompileError.genericError(
            GenericError.new(nd.csr, cmp.fmt(
                "Redefinition of type {s}",
                .{name},
            )),
        )) catch allocate.reportAndExit();
        return;
    }

    var t = allocate.create(cmp.alloc, Type);
    t.* = Type{
        .Class = Type.ClassType.new(
            null,
            clsNd.name,
            &[_]Type.ClassType.Member{},
        ),
    };

    cmp.scope.putType(name, t);
}

fn resolveSuperType(
    cmp: *Compiler,
    csr: Cursor,
    extends: ?[]const u8,
) ?Type.Ptr {
    if (extends) |clsName| {
        var nd = node.NodeImpl{
            .csr = csr,
            .data = node.NodeData{ .TypeName = clsName },
            .ty = null,
        };

        if (cmp.findType(&nd)) |ty| {
            if (ty.getType() == .Class) {
                return ty;
            } else {
                cmp.errors.append(CompileError.genericError(
                    GenericError.new(csr, cmp.fmt(
                        "Superclass '{s}' is not a class",
                        .{clsName},
                    )),
                )) catch allocate.reportAndExit();
            }
        } else {
            cmp.errors.append(CompileError.genericError(
                GenericError.new(csr, cmp.fmt(
                    "Superclass '{s}' is not in scope",
                    .{clsName},
                )),
            )) catch allocate.reportAndExit();
        }
    }

    return null;
}

fn resolveMemberType(
    cmp: *Compiler,
    csr: Cursor,
    className: []const u8,
    member: node.ClassTypeMember,
) Type.Ptr {
    if (member.ty) |tyNode| {
        if (cmp.findType(tyNode)) |ty| {
            return ty;
        } else {
            cmp.errors.append(CompileError.genericError(
                GenericError.new(tyNode.csr, cmp.fmt(
                    "Cannot resolve type for member '{s}' of class '{s}'",
                    .{ member.name, className },
                )),
            )) catch allocate.reportAndExit();
            return cmp.typebook.getAny();
        }
    }

    return cmp.implicitAny(csr, member.name);
}

pub fn processClass(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == NodeType.ClassType);

    const clsNd = nd.data.ClassType;

    var clsT = if (cmp.scope.getTypeMut(clsNd.name)) |clsTy|
        clsTy
    else
        std.debug.panic("Class '{s}' has not been prepared", .{clsNd.name});

    std.debug.assert(clsT.getType() == .Class);

    var cls = &clsT.Class;

    cls.super = resolveSuperType(cmp, nd.csr, clsNd.extends);

    cls.members = allocate.alloc(
        cmp.alloc,
        Type.ClassType.Member,
        clsNd.members.items.len,
    );

    for (clsNd.members.items) |memberNd, index| {
        std.debug.assert(memberNd.getType() == .ClassTypeMember);
        const member = memberNd.data.ClassTypeMember;

        cls.members[index] = Type.ClassType.Member{
            .name = member.name,
            .ty = resolveMemberType(cmp, memberNd.csr, cls.name, member),
            .visibility = member.visibility,
        };
    }

    cmp.typebook.putClass(clsT);

    if (cmp.scope.getLocal(clsNd.name)) |previous| {
        cmp.errors.append(CompileError.redefinitionError(
            RedefinitionError.new(clsNd.name, previous.csr, nd.csr),
        )) catch allocate.reportAndExit();
        return;
    }

    // TODO: This should take the arguments to the constructor
    const constructorTy = cmp.typebook.getFunction(clsT, &[_]Type.Ptr{}, true);
    cmp.scope.put(clsNd.name, constructorTy, true, nd.csr);
}

test "can compile an empty class declaration" {
    try (CompilerTestCase{
        .code = "class A {}",
    }).run();
}

test "can compile a class declaration with a superclass" {
    try (CompilerTestCase{
        .code = "class A {} class B extends A { private a: number; }",
    }).run();
}

test "superclass must be defined" {
    try (CompilerTestCase{
        .code = "class B extends A { private a: number; }",
        .check = (struct {
            pub fn check(case: CompilerTestCase, cmp: Compiler) anyerror!void {
                try case.expectEqual(@intCast(usize, 1), cmp.errors.count());
                const err = cmp.getError(0);
                try case.expectEqual(err.getType(), .GenericError);
                try case.expectEqualStrings(
                    "Superclass 'A' is not in scope",
                    err.GenericError.msg,
                );
            }
        }).check,
    }).run();
}

test "superclass must be a class" {
    try (CompilerTestCase{
        .code = "class B extends number { private a: number; }",
        .check = (struct {
            pub fn check(case: CompilerTestCase, cmp: Compiler) anyerror!void {
                try case.expectEqual(@intCast(usize, 1), cmp.errors.count());
                const err = cmp.getError(0);
                try case.expectEqual(err.getType(), .GenericError);
                try case.expectEqualStrings(
                    "Superclass 'number' is not a class",
                    err.GenericError.msg,
                );
            }
        }).check,
    }).run();
}

test "class member types must be valid" {
    try (CompilerTestCase{
        .code = "class A { private a: SomeType; }",
        .check = (struct {
            pub fn check(case: CompilerTestCase, cmp: Compiler) anyerror!void {
                try case.expectEqual(@intCast(usize, 1), cmp.errors.count());
                const err = cmp.getError(0);
                try case.expectEqual(err.getType(), .GenericError);
                try case.expectEqualStrings(
                    "Cannot resolve type for member 'a' of class 'A'",
                    err.GenericError.msg,
                );
            }
        }).check,
    }).run();
}

test "classes share scope with variables" {
    try (CompilerTestCase{
        .code = "class A {} const A = 0;",
        .check = (struct {
            pub fn check(case: CompilerTestCase, cmp: Compiler) anyerror!void {
                try case.expectEqual(@intCast(usize, 1), cmp.errors.count());
                const err = cmp.getError(0);
                try case.expectEqual(err.getType(), .RedefinitionError);
                try case.expectEqualStrings("A", err.RedefinitionError.name);
                try case.expectEqual(
                    Cursor.new(1, 1),
                    err.RedefinitionError.firstDefined,
                );
                try case.expectEqual(
                    Cursor.new(1, 12),
                    err.RedefinitionError.secondDefined,
                );
            }
        }).check,
    }).run();
}
