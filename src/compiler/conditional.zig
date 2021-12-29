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
const Compiler = @import("compiler.zig").Compiler;
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const Type = @import("../common/types/type.zig").Type;
const GenericError = @import("errors/generic_error.zig").GenericError;
const CompileError = @import("errors/compile_error.zig").CompileError;
const CompilerTestCase = @import("compiler_test_case.zig").CompilerTestCase;
const allocate = @import("../common/allocate.zig");

pub fn processConditional(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == .If);

    const cond = nd.data.If;

    for (cond.branches.items) |branch| {
        _ = cmp.inferExprType(branch.cond);
        cmp.processNode(branch.ifTrue);
    }

    if (cond.elseBranch) |branch| {
        cmp.processNode(branch);
    }
}

test "can compile simple 'if' statement" {
    try (CompilerTestCase{
        .code = "if (true) var a = 6;",
    }).run();
}

test "can compile 'if' statement with 'else'" {
    try (CompilerTestCase{
        .code = "if (true) var a = 6; else var b = 7;",
    }).run();
}

test "can compile 'if' statement with 'else if'" {
    try (CompilerTestCase{
        .code = "if (true) var a = 6; else if (false) var b = 7;",
    }).run();
}

test "can compile 'if' statement with multiple 'else if'" {
    try (CompilerTestCase{
        .code = 
        \\if (true) var a = 6;
        \\else if (false) var b = 7;
        \\else if (3) var c = 8;
        \\else if (4) var d = 9;
        ,
    }).run();
}

test "can compile 'if' statement with multiple 'else if' and 'else'" {
    try (CompilerTestCase{
        .code = 
        \\if (true) var a = 6;
        \\else if (false) var b = 7;
        \\else if (3) var c = 8;
        \\else if (4) var d = 9;
        \\else var e = 10;
        ,
    }).run();
}

pub fn processSwitch(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == .Switch);

    const sw = nd.data.Switch;

    const exprTy = cmp.inferExprType(sw.expr) orelse return;

    cmp.scope.ctx = .Switch;

    for (sw.cases.items) |case| {
        if (cmp.inferExprType(case.value)) |valueTy| {
            if (!valueTy.isAssignableTo(exprTy)) {
                cmp.errors.append(CompileError.genericError(
                    GenericError.new(
                        case.value.csr,
                        "Case type does not match switch type",
                    ),
                )) catch allocate.reportAndExit();
            }
        }

        for (case.stmts.items) |stmt|
            cmp.processNode(stmt);
    }

    if (sw.default) |default| {
        for (default.items) |stmt|
            cmp.processNode(stmt);
    }

    cmp.scope.ctx = null;
}

test "can compile 'switch' statement" {
    try (CompilerTestCase{
        .code = 
        \\switch (2) {
        \\  case 1: null;
        \\  case 2: undefined; break;
        \\  default: return;
        \\}
        ,
    }).run();
}
