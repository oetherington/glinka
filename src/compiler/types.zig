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

    cmp.scope.putType(name, cmp.typebook.getAlias(name, ty));
}

test "can compile a type alias declaration" {
    try (CompilerTestCase{
        .code = "type ATypeAlias = number | boolean;",
    }).run();
}

pub fn processInterface(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == NodeType.InterfaceType);

    const in = nd.data.InterfaceType;

    const name = if (in.name) |nm|
        nm
    else
        std.debug.panic("Invalid InterfaceType node (has no name)", .{});

    const ty = cmp.findType(nd) orelse {
        cmp.errors.append(CompileError.genericError(
            GenericError.new(nd.csr, cmp.fmt(
                "Interface type {s} is invalid",
                .{name},
            )),
        )) catch allocate.reportAndExit();
        return;
    };

    std.debug.assert(ty.getType() == .Interface);

    cmp.scope.putType(name, ty);
}

test "can compile an interface declaration" {
    try (CompilerTestCase{
        .code = "interface Inter { aString: string; aUnion: number | null; }",
    }).run();
}

pub fn processClass(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == NodeType.ClassType);

    // TODO
    _ = cmp;
}

test "can compile a class declaration" {
    try (CompilerTestCase{
        .code = "class MyClass {}",
    }).run();
}
