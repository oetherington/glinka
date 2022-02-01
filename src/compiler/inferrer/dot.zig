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

pub fn inferDotType(
    cmp: *Compiler,
    nd: node.Node,
    ctx: *const InferContext,
    dot: node.Dot,
) InferResult {
    const subCtx = InferContext.none(ctx);
    const expr = inferExprType(cmp, dot.expr, &subCtx);
    switch (expr) {
        .Success => |exprTy| {
            if (exprTy.getType() == .Interface) {
                const mem = exprTy.Interface.getNamedMember(dot.ident);
                if (mem == null)
                    return InferResult.err(CompileError.genericError(
                        GenericError.new(
                            nd.csr,
                            cmp.fmt(
                                "Object property {s} does not exist",
                                .{dot.ident},
                            ),
                        ),
                    ));

                nd.ty = mem.?.ty;
            } else if (exprTy.getType() == .Class) {
                const mem = exprTy.Class.getNamedMember(dot.ident);
                if (mem == null)
                    return InferResult.err(CompileError.genericError(
                        GenericError.new(
                            nd.csr,
                            cmp.fmt(
                                "Class {s} has no member called {s}",
                                .{ exprTy.Class.name, dot.ident },
                            ),
                        ),
                    ));

                // TODO: Check member visibility
                nd.ty = mem.?.ty;
            } else {
                return InferResult.err(CompileError.genericError(
                    GenericError.new(
                        nd.csr,
                        cmp.fmt(
                            "Using '.' operator on non-object value",
                            .{},
                        ),
                    ),
                ));
            }
        },
        .Error => return expr,
    }

    return InferResult.success(nd.ty.?);
}

test "can infer type of a dot expression with an object" {
    const nd = node.makeNode(
        std.testing.allocator,
        Cursor.new(1, 1),
        .Ident,
        "console",
    );
    defer std.testing.allocator.destroy(nd);

    try (InferTestCase{
        .check = (struct {
            fn check(
                scope: *Scope,
                typebook: *TypeBook,
                res: InferResult,
            ) anyerror!void {
                _ = scope;

                try InferTestCase.expectSuccess(res);

                const ty = res.Success;
                const consoleLogTy = typebook.getFunction(
                    typebook.getVoid(),
                    &[_]Type.Ptr{typebook.getAny()},
                    false,
                );

                try std.testing.expectEqual(Type.Type.Function, ty.getType());
                try std.testing.expectEqual(consoleLogTy, ty);
            }
        }).check,
    }).run(.Dot, node.Dot{ .expr = nd, .ident = "log" });
}

test "can infer type of a dot expression with a class" {
    const nd = node.makeNode(
        std.testing.allocator,
        Cursor.new(1, 1),
        .Ident,
        "myInstance",
    );
    defer std.testing.allocator.destroy(nd);

    try (InferTestCase{
        .setup = (struct {
            fn setup(
                scope: *Scope,
                typebook: *TypeBook,
            ) anyerror!void {
                var members = allocate.alloc(
                    std.testing.allocator,
                    Type.ClassType.Member,
                    1,
                );
                members[0] = Type.ClassType.Member{
                    .name = "member",
                    .ty = typebook.getNumber(),
                    .visibility = .Public,
                };

                var ty = allocate.create(std.testing.allocator, Type);
                ty.* = Type{
                    .Class = Type.ClassType.new(null, "MyClass", members),
                };

                typebook.putClass(ty);
                scope.putType("MyClass", ty);
                scope.put(
                    "MyClass",
                    typebook.getFunction(ty, &[_]Type.Ptr{}, true),
                    true,
                    Cursor.new(0, 0),
                );

                scope.put("myInstance", ty, true, Cursor.new(0, 0));
            }
        }).setup,
        .check = (struct {
            fn check(
                scope: *Scope,
                typebook: *TypeBook,
                res: InferResult,
            ) anyerror!void {
                _ = scope;

                try InferTestCase.expectSuccess(res);
                try std.testing.expectEqual(typebook.getNumber(), res.Success);
            }
        }).check,
    }).run(.Dot, node.Dot{ .expr = nd, .ident = "member" });
}
