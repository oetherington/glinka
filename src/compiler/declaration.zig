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
const TypeError = @import("errors/type_error.zig").TypeError;
const RedefinitionError = @import("errors/redefinition_error.zig").RedefinitionError;
const GenericError = @import("errors/generic_error.zig").GenericError;
const CompileError = @import("errors/compile_error.zig").CompileError;
const CompilerTestCase = @import("compiler_test_case.zig").CompilerTestCase;
const allocate = @import("../common/allocate.zig");

fn declWithAssign(cmp: *Compiler, csr: Cursor, decl: node.Decl) void {
    std.debug.assert(decl.value != null);

    if (cmp.inferExprType(decl.value.?)) |valueTy| {
        const isConst = decl.scoping == .Const;

        if (decl.ty) |annotationNode| {
            if (cmp.findType(annotationNode)) |annotation| {
                if (!valueTy.isAssignableTo(annotation)) {
                    cmp.errors.append(CompileError.typeError(
                        TypeError.new(csr, valueTy, annotation),
                    )) catch allocate.reportAndExit();
                }

                cmp.scope.put(decl.name, annotation, isConst, csr);
            } else {
                annotationNode.dump();
                cmp.errors.append(CompileError.genericError(
                    GenericError.new(csr, "Invalid type annotation"),
                )) catch allocate.reportAndExit();
                cmp.scope.put(decl.name, valueTy, isConst, csr);
            }
        } else {
            cmp.scope.put(decl.name, valueTy, isConst, csr);
        }
    }
}

fn declWithoutAssign(cmp: *Compiler, csr: Cursor, decl: node.Decl) void {
    std.debug.assert(decl.value == null);

    if (decl.scoping == .Const) {
        cmp.errors.append(CompileError.genericError(
            GenericError.new(csr, "Constant value must be initialized"),
        )) catch allocate.reportAndExit();
        return;
    }

    const annotation = if (decl.ty) |ty|
        cmp.findType(ty)
    else
        cmp.implicitAny(csr, decl.name);

    if (annotation) |ty| {
        cmp.scope.put(decl.name, ty, false, csr);
    } else {
        cmp.errors.append(CompileError.genericError(
            GenericError.new(
                csr,
                cmp.fmt("Invalid type for variable '{s}'", .{decl.name}),
            ),
        )) catch allocate.reportAndExit();
    }
}

pub fn processDecl(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == NodeType.Decl);

    const decl = nd.data.Decl;

    if (cmp.scope.getLocal(decl.name)) |previous| {
        cmp.errors.append(CompileError.redefinitionError(
            RedefinitionError.new(decl.name, previous.csr, nd.csr),
        )) catch allocate.reportAndExit();
        return;
    }

    if (decl.value) |_|
        declWithAssign(cmp, nd.csr, decl)
    else
        declWithoutAssign(cmp, nd.csr, decl);
}

test "constants must be initialized" {
    try (CompilerTestCase{
        .code = "const aVariable;",
        .check = (struct {
            fn check(case: CompilerTestCase, cmp: Compiler) anyerror!void {
                try case.expectEqual(@intCast(usize, 1), cmp.errors.count());

                const err = cmp.getError(0);
                try case.expectEqual(
                    CompileError.Type.GenericError,
                    err.getType(),
                );
                try case.expectEqualStrings(
                    "Constant value must be initialized",
                    err.GenericError.msg,
                );
            }
        }).check,
    }).run();
}

test "uninitialized and untyped variable has implicit any type" {
    try (CompilerTestCase{
        .code = "let aVariable;",
        .check = (struct {
            fn check(case: CompilerTestCase, cmp: Compiler) anyerror!void {
                try case.expectEqual(@intCast(usize, 1), cmp.errors.count());

                const err = cmp.getError(0);
                try case.expectEqual(
                    CompileError.Type.ImplicitAnyError,
                    err.getType(),
                );
                try case.expectEqualStrings(
                    "aVariable",
                    err.ImplicitAnyError.symbol,
                );
            }
        }).check,
    }).run();
}

test "can compile a 'let' declaration without assigning a value" {
    try (CompilerTestCase{
        .code = "let aVariable: number;",
    }).run();
}

test "can compile a 'var' declaration without assigning a value" {
    try (CompilerTestCase{
        .code = "var aVariable: string;",
    }).run();
}

test "can compile a 'const' declaration with an assigned value" {
    try (CompilerTestCase{
        .code = "const aVariable: string = 'hello world';",
    }).run();
}

test "can compile a 'let' declaration with an assigned value" {
    try (CompilerTestCase{
        .code = "let aVariable: number = 3;",
    }).run();
}

test "can compile a 'var' declaration with an assigned value" {
    try (CompilerTestCase{
        .code = "var aVariable: boolean = true;",
    }).run();
}

test "can compile a 'const' declaration with an inferred type" {
    try (CompilerTestCase{
        .code = "const aVariable = 'hello world';",
    }).run();
}

test "can compile a 'let' declaration with an inferred type" {
    try (CompilerTestCase{
        .code = "let aVariable = 1234;",
    }).run();
}

test "can compile a 'var' declaration with an inferred type" {
    try (CompilerTestCase{
        .code = "var aVariable = false;",
    }).run();
}

test "declarations cannot be redefined in the same scope" {
    try (CompilerTestCase{
        .code = "let a = 3; let a = 4;",
        .check = (struct {
            fn check(case: CompilerTestCase, cmp: Compiler) anyerror!void {
                try case.expectEqual(@intCast(usize, 1), cmp.errors.count());

                const err = cmp.getError(0);
                try case.expectEqual(
                    CompileError.Type.RedefinitionError,
                    err.getType(),
                );
                try case.expectEqualStrings("a", err.RedefinitionError.name);
                try case.expectEqual(
                    @intCast(u32, 1),
                    err.RedefinitionError.firstDefined.ln,
                );
                try case.expectEqual(
                    @intCast(u32, 1),
                    err.RedefinitionError.firstDefined.ch,
                );
                try case.expectEqual(
                    @intCast(u32, 1),
                    err.RedefinitionError.secondDefined.ln,
                );
                try case.expectEqual(
                    @intCast(u32, 12),
                    err.RedefinitionError.secondDefined.ch,
                );
            }
        }).check,
    }).run();
}

test "declarations can be redefined in different scopes" {
    try (CompilerTestCase{
        .code = "let a = 3; { let a = 4; }",
    }).run();
}
