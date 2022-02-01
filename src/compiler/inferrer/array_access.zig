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
const Cursor = @import("../../common/cursor.zig").Cursor;
const Type = @import("../../common/types/type.zig").Type;
const Compiler = @import("../compiler.zig").Compiler;
const Scope = @import("../scope.zig").Scope;
const TypeBook = @import("../typebook.zig").TypeBook;
const CompileError = @import("../errors/compile_error.zig").CompileError;
const GenericError = @import("../errors/generic_error.zig").GenericError;
const TypeError = @import("../errors/type_error.zig").TypeError;
const node = @import("../../common/node.zig");
const InferResult = @import("infer_result.zig").InferResult;
const InferContext = @import("infer_context.zig").InferContext;
const InferTestCase = @import("infer_test_case.zig").InferTestCase;
const inferExprType = @import("inferrer.zig").inferExprType;

pub fn inferArrayAccessType(
    cmp: *Compiler,
    nd: node.Node,
    ctx: InferContext,
    access: node.ArrayAccess,
) InferResult {
    _ = ctx; // TODO

    const expr = inferExprType(cmp, access.expr, .None);
    if (expr.getType() != .Success)
        return expr;

    const exprTy = expr.Success;
    if (exprTy.getType() != .Array) {
        return InferResult.err(CompileError.genericError(
            GenericError.new(
                access.expr.csr,
                "Invalid array access - expression is not an array",
            ),
        ));
    }

    const index = inferExprType(cmp, access.index, .None);
    if (index.getType() != .Success)
        return index;

    const indexTy = index.Success;
    if (indexTy.getType() != .Number) {
        return InferResult.err(CompileError.typeError(
            TypeError.new(
                access.index.csr,
                indexTy,
                cmp.typebook.getNumber(),
            ),
        ));
    }

    nd.ty = exprTy.Array.subtype;
    return InferResult.success(nd.ty.?);
}

test "can infer type of an array access" {
    const alloc = std.testing.allocator;
    const csr = Cursor.new(0, 0);

    const expr = node.makeNode(alloc, csr, .Ident, "anArray");
    const index = node.makeNode(alloc, csr, .Int, "1");
    defer alloc.destroy(expr);
    defer alloc.destroy(index);

    try (InferTestCase{
        .setup = (struct {
            fn setup(
                scope: *Scope,
                typebook: *TypeBook,
            ) anyerror!void {
                scope.put(
                    "anArray",
                    typebook.getArray(typebook.getString()),
                    true,
                    Cursor.new(0, 0),
                );
            }
        }).setup,
        .check = (struct {
            fn check(
                scope: *Scope,
                typebook: *TypeBook,
                res: InferResult,
            ) anyerror!void {
                _ = scope;
                _ = typebook;

                try std.testing.expectEqual(
                    InferResult.Variant.Success,
                    res.getType(),
                );
                try std.testing.expectEqual(
                    Type.Type.String,
                    res.Success.getType(),
                );
            }
        }).check,
    }).run(.ArrayAccess, node.ArrayAccess{
        .expr = expr,
        .index = index,
    });
}
