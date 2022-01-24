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
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const Type = @import("../common/types/type.zig").Type;
const GenericError = @import("errors/generic_error.zig").GenericError;
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

pub fn hoistClass(cmp: *Compiler, nd: Node) void {
    // TODO
    _ = cmp;
    _ = nd;
}

pub fn processClass(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == NodeType.ClassType);

    const clsNd = nd.data.ClassType;

    const super: ?Type.Ptr = if (clsNd.extends) |_|
        null // TODO: Lookup superclass by name
    else
        null;

    var members = std.ArrayList(Type.ClassType.Member).init(cmp.alloc);
    _ = members;

    // const cls = Type.ClassType.new(super, clsNd.name, members.items);

    // TODO
    _ = cmp;
    _ = clsNd;
    _ = super;
}

test "can compile a class declaration" {
    try (CompilerTestCase{
        .code = "class MyClass {}",
    }).run();
}
