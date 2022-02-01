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
const node = @import("../../common/node.zig");
const InferResult = @import("infer_result.zig").InferResult;
const InferContext = @import("infer_context.zig").InferContext;
const InferTestCase = @import("infer_test_case.zig").InferTestCase;
const inferExprType = @import("inferrer.zig").inferExprType;
const allocate = @import("../../common/allocate.zig");

pub fn inferNewType(
    cmp: *Compiler,
    nd: node.Node,
    ctx: InferContext,
    new: node.Node,
) InferResult {
    _ = ctx; // TODO

    const res = inferExprType(cmp, new, .New);
    if (res.getType() != .Success)
        return res;

    const ty = res.Success;

    if (new.getType() == .Call) {
        // We already checked the expression is constructable is the
        // call to inferExprType above
        nd.ty = ty;
    } else {
        if (ty.getType() != .Function or !ty.Function.isConstructable) {
            return InferResult.err(CompileError.genericError(
                GenericError.new(
                    nd.csr,
                    "Expression type is not constructable",
                ),
            ));
        }

        nd.ty = ty.Function.ret;
    }

    return InferResult.success(nd.ty.?);
}

test "can infer type of a new expression with an Ident" {
    const nd = node.makeNode(
        std.testing.allocator,
        Cursor.new(1, 1),
        .Ident,
        "MyClass",
    );
    defer std.testing.allocator.destroy(nd);

    try (InferTestCase{
        .setup = (struct {
            fn setup(
                scope: *Scope,
                typebook: *TypeBook,
            ) anyerror!void {
                var ty = allocate.create(std.testing.allocator, Type);
                ty.* = Type{
                    .Class = Type.ClassType.new(
                        null,
                        "MyClass",
                        &[_]Type.ClassType.Member{},
                    ),
                };

                typebook.putClass(ty);
                scope.putType("MyClass", ty);
                scope.put(
                    "MyClass",
                    typebook.getFunction(ty, &[_]Type.Ptr{}, true),
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
                _ = typebook;

                try InferTestCase.expectSuccess(res);

                const ty = res.Success;
                const classTy = scope.getType("MyClass").?;

                try std.testing.expectEqual(Type.Type.Class, ty.getType());
                try std.testing.expectEqual(classTy, ty);
            }
        }).check,
    }).run(.New, nd);
}
