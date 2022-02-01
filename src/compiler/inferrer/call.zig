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

pub fn inferCallType(
    cmp: *Compiler,
    nd: node.Node,
    ctx: InferContext,
    call: node.Call,
) InferResult {
    _ = ctx; // TODO

    const func = inferExprType(cmp, call.expr, .None);
    if (func.getType() != .Success)
        return func;

    if (func.Success.getType() != .Function) {
        return InferResult.err(CompileError.genericError(
            GenericError.new(
                call.expr.csr,
                if (call.expr.getType() == .Ident)
                    cmp.fmt(
                        "Variable '{s}' is not a function",
                        .{call.expr.data.Ident},
                    )
                else
                    "Calling a value that is not a function",
            ),
        ));
    }

    const funcTy = func.Success.Function;

    if (funcTy.isConstructable and ctx != .New) {
        return InferResult.err(CompileError.genericError(
            GenericError.new(
                call.expr.csr,
                "Value is not callable. Did you mean to include 'new'?",
            ),
        ));
    }

    if (!funcTy.isConstructable and ctx == .New) {
        // TODO: Check for errorOnImplicitAny in config
        return InferResult.err(CompileError.genericError(
            GenericError.new(
                call.expr.csr,
                "'new' expression, whose target lacks a construct signature, implicitly has an 'any' type",
            ),
        ));
    }

    if (funcTy.args.len != call.args.items.len) {
        return InferResult.err(CompileError.genericError(
            GenericError.new(
                call.expr.csr,
                cmp.fmt(
                    "Function expected {d} arguments but found {d}",
                    .{ funcTy.args.len, call.args.items.len },
                ),
            ),
        ));
    }

    for (call.args.items) |arg, index| {
        const res = inferExprType(cmp, arg, .None);
        if (res.getType() != .Success)
            return res;

        const ty = res.Success;
        const argTy = funcTy.args[index];
        if (!ty.isAssignableTo(argTy)) {
            return InferResult.err(CompileError.typeError(
                TypeError.new(arg.csr, ty, argTy),
            ));
        }
    }

    nd.ty = funcTy.ret;
    return InferResult.success(nd.ty.?);
}

test "can infer type of function call with no arguments" {
    const alloc = std.testing.allocator;

    const func = node.makeNode(alloc, Cursor.new(0, 0), .Ident, "aFunction");
    defer alloc.destroy(func);

    const args = node.NodeList{};

    try (InferTestCase{
        .expectedTy = .Boolean,
        .setup = (struct {
            fn setup(
                scope: *Scope,
                typebook: *TypeBook,
            ) anyerror!void {
                scope.put(
                    "aFunction",
                    typebook.getFunction(
                        typebook.getBoolean(),
                        &[_]Type.Ptr{},
                        false,
                    ),
                    true,
                    Cursor.new(0, 0),
                );
            }
        }).setup,
    }).run(.Call, .{
        .expr = func,
        .args = args,
    });
}

test "can infer type of function call with arguments" {
    const alloc = std.testing.allocator;

    const func = node.makeNode(alloc, Cursor.new(0, 0), .Ident, "aFunction");
    defer alloc.destroy(func);

    const arg1 = node.makeNode(alloc, Cursor.new(0, 0), .Int, "34");
    const arg2 = node.makeNode(alloc, Cursor.new(0, 0), .String, "a string");
    defer alloc.destroy(arg1);
    defer alloc.destroy(arg2);

    var args = node.NodeList{};
    defer args.deinit(alloc);
    try args.append(alloc, arg1);
    try args.append(alloc, arg2);

    try (InferTestCase{
        .expectedTy = .Boolean,
        .setup = (struct {
            fn setup(
                scope: *Scope,
                typebook: *TypeBook,
            ) anyerror!void {
                scope.put(
                    "aFunction",
                    typebook.getFunction(
                        typebook.getBoolean(),
                        &[_]Type.Ptr{
                            typebook.getNumber(),
                            typebook.getString(),
                        },
                        false,
                    ),
                    true,
                    Cursor.new(0, 0),
                );
            }
        }).setup,
    }).run(.Call, .{
        .expr = func,
        .args = args,
    });
}

test "an error is thrown when calling a function with a wrong argument count" {
    const alloc = std.testing.allocator;

    const func = node.makeNode(alloc, Cursor.new(0, 0), .Ident, "aFunction");
    defer alloc.destroy(func);

    const arg = node.makeNode(alloc, Cursor.new(0, 0), .Int, "34");
    defer alloc.destroy(arg);

    var args = node.NodeList{};
    defer args.deinit(alloc);
    try args.append(alloc, arg);

    try (InferTestCase{
        .setup = (struct {
            fn setup(
                scope: *Scope,
                typebook: *TypeBook,
            ) anyerror!void {
                scope.put(
                    "aFunction",
                    typebook.getFunction(
                        typebook.getBoolean(),
                        &[_]Type.Ptr{
                            typebook.getNumber(),
                            typebook.getString(),
                        },
                        false,
                    ),
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
                    InferResult.Variant.Error,
                    res.getType(),
                );

                const err = res.Error;
                try std.testing.expectEqual(
                    CompileError.Type.GenericError,
                    err.getType(),
                );
                try std.testing.expectEqualStrings(
                    "Function expected 2 arguments but found 1",
                    err.GenericError.msg,
                );
            }
        }).check,
    }).run(.Call, .{
        .expr = func,
        .args = args,
    });
}

test "an error is thrown if function arguments have incorrect types" {
    const alloc = std.testing.allocator;

    const func = node.makeNode(alloc, Cursor.new(0, 0), .Ident, "aFunction");
    defer alloc.destroy(func);

    const arg = node.makeNode(alloc, Cursor.new(0, 0), .Int, "34");
    defer alloc.destroy(arg);

    var args = node.NodeList{};
    defer args.deinit(alloc);
    try args.append(alloc, arg);

    try (InferTestCase{
        .setup = (struct {
            fn setup(
                scope: *Scope,
                typebook: *TypeBook,
            ) anyerror!void {
                scope.put(
                    "aFunction",
                    typebook.getFunction(
                        typebook.getBoolean(),
                        &[_]Type.Ptr{typebook.getString()},
                        false,
                    ),
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

                try std.testing.expectEqual(
                    InferResult.Variant.Error,
                    res.getType(),
                );

                const err = res.Error;
                try std.testing.expectEqual(
                    CompileError.Type.TypeError,
                    err.getType(),
                );
                try std.testing.expectEqual(
                    err.TypeError.valueTy,
                    typebook.getNumber(),
                );
                try std.testing.expectEqual(
                    err.TypeError.targetTy,
                    typebook.getString(),
                );
            }
        }).check,
    }).run(.Call, .{
        .expr = func,
        .args = args,
    });
}
