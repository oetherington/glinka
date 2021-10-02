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
const Compiler = @import("compiler.zig").Compiler;
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const Type = @import("../common/types/type.zig").Type;
const TypeError = @import("errors/type_error.zig").TypeError;
const GenericError = @import("errors/generic_error.zig").GenericError;
const CompileError = @import("errors/compile_error.zig").CompileError;
const CompilerTestCase = @import("compiler_test_case.zig").CompilerTestCase;

pub fn processExpression(cmp: *Compiler, nd: Node) void {
    _ = cmp.inferExprType(nd);
}

test "can compile assign expressions" {
    try (CompilerTestCase{
        .code = "var aVariable = 3; aVariable = 4; aVariable += 3;",
    }).run();
}

test "assign expressions are type checked" {
    try (CompilerTestCase{
        .code = "var aVariable = false; aVariable = 3;",
        .check = (struct {
            fn check(case: CompilerTestCase, cmp: Compiler) anyerror!void {
                try case.expectEqual(@intCast(usize, 1), cmp.errors.count());

                const err = cmp.getError(0);
                try case.expectEqual(
                    CompileError.Type.AssignError,
                    err.getType(),
                );
                try case.expectEqual(
                    cmp.typebook.getBoolean(),
                    err.AssignError.left,
                );
                try case.expectEqual(
                    cmp.typebook.getNumber(),
                    err.AssignError.right,
                );
            }
        }).check,
    }).run();
}

test "can compile prefix expressions" {
    try (CompilerTestCase{
        .code = "let aVariable = 4; ++aVariable; --aVariable;",
    }).run();
}

test "prefix expressions are type checked" {
    try (CompilerTestCase{
        .code = "let aVariable = 'a string'; ++aVariable; --aVariable;",
        .check = (struct {
            fn check(case: CompilerTestCase, cmp: Compiler) anyerror!void {
                try case.expectEqual(@intCast(usize, 2), cmp.errors.count());

                try case.expectEqual(
                    CompileError.Type.OpError,
                    cmp.getError(0).getType(),
                );
                try case.expectEqual(
                    CompileError.Type.OpError,
                    cmp.getError(1).getType(),
                );
            }
        }).check,
    }).run();
}

test "can compile postfix expressions" {
    try (CompilerTestCase{
        .code = "let aVariable = 4; aVariable++; aVariable--;",
    }).run();
}

test "postfix expressions are type checked" {
    try (CompilerTestCase{
        .code = "let aVariable = 'a string'; aVariable++; aVariable--;",
        .check = (struct {
            fn check(case: CompilerTestCase, cmp: Compiler) anyerror!void {
                try case.expectEqual(@intCast(usize, 2), cmp.errors.count());

                try case.expectEqual(
                    CompileError.Type.OpError,
                    cmp.getError(0).getType(),
                );
                try case.expectEqual(
                    CompileError.Type.OpError,
                    cmp.getError(1).getType(),
                );
            }
        }).check,
    }).run();
}

test "can compile ternary expressions" {
    try (CompilerTestCase{
        .code = "true ? 1 : 0;",
    }).run();
}
