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
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const Cursor = @import("../common/cursor.zig").Cursor;
const Config = @import("../common/config.zig").Config;
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Compiler = @import("compiler.zig").Compiler;
const Scope = @import("scope.zig").Scope;
const TypeBook = @import("typebook.zig").TypeBook;
const Type = @import("../common/types/type.zig").Type;
const CompileError = @import("errors/compile_error.zig").CompileError;
const OpError = @import("errors/op_error.zig").OpError;
const AssignError = @import("errors/assign_error.zig").AssignError;
const GenericError = @import("errors/generic_error.zig").GenericError;
const TypeError = @import("errors/type_error.zig").TypeError;
const NopBackend = @import("compiler_test_case.zig").NopBackend;
const allocate = @import("../common/allocate.zig");

pub const InferResult = union(Variant) {
    pub const Variant = enum {
        Success,
        Error,
    };

    Success: Type.Ptr,
    Error: CompileError,

    pub fn success(ty: Type.Ptr) InferResult {
        return InferResult{
            .Success = ty,
        };
    }

    pub fn err(e: CompileError) InferResult {
        return InferResult{
            .Error = e,
        };
    }

    pub fn getType(self: InferResult) Variant {
        return @as(Variant, self);
    }
};

test "can create a success InferResult" {
    const boolean = Type.newBoolean();
    const ptr = &boolean;
    const result = InferResult.success(ptr);
    try expectEqual(InferResult.Success, result.getType());
    try expectEqual(ptr, result.Success);
}

test "can create an error InferResult" {
    const cursor = Cursor.new(2, 5);
    const symbol = "anySymbol";
    const implicitAnyError = @import("errors/implicit_any_error.zig");
    const ImplicitAnyError = implicitAnyError.ImplicitAnyError;
    const err = ImplicitAnyError.new(cursor, symbol);
    const compileError = CompileError.implicitAnyError(err);
    const result = InferResult.err(compileError);
    try expectEqual(InferResult.Error, result.getType());
    try expectEqual(CompileError.Type.ImplicitAnyError, result.Error.getType());
    const e = result.Error.ImplicitAnyError;
    try expectEqual(cursor, e.csr);
    try expectEqualStrings(symbol, e.symbol);
}

pub fn inferExprType(cmp: *Compiler, nd: Node) InferResult {
    switch (nd.data) {
        .Int => nd.ty = cmp.typebook.getNumber(),
        .String, .Template => nd.ty = cmp.typebook.getString(),
        .True, .False => nd.ty = cmp.typebook.getBoolean(),
        .Null => nd.ty = cmp.typebook.getNull(),
        .Undefined => nd.ty = cmp.typebook.getUndefined(),
        .Ident => |ident| nd.ty = if (cmp.scope.get(ident)) |sym|
            sym.ty
        else
            cmp.typebook.getUndefined(),
        .PrefixOp, .PostfixOp => |op| {
            const expr = switch (inferExprType(cmp, op.expr)) {
                .Success => |res| res,
                .Error => |err| return InferResult.err(err),
            };

            const entry = cmp.typebook.getOpEntry(op.op);

            // We assume it's unary, otherwise the Node wouldn't have parsed
            if (entry == null or !expr.isAssignableTo(entry.?.Unary.input)) {
                return InferResult.err(CompileError.opError(OpError.new(
                    nd.csr,
                    op.op,
                    expr,
                )));
            }

            nd.ty = if (entry.?.Unary.output) |out| out else expr;
        },
        .BinaryOp => |op| {
            const left = switch (inferExprType(cmp, op.left)) {
                .Success => |res| res,
                .Error => |err| return InferResult.err(err),
            };

            const right = switch (inferExprType(cmp, op.right)) {
                .Success => |res| res,
                .Error => |err| return InferResult.err(err),
            };

            if (!right.isAssignableTo(left)) {
                return InferResult.err(CompileError.assignError(
                    AssignError.new(nd.csr, left, right),
                ));
            }

            const entry = cmp.typebook.getOpEntry(op.op);

            // We assume it's binary, otherwise the Node wouldn't have parsed
            if (entry == null or !left.isAssignableTo(entry.?.Binary.input)) {
                return InferResult.err(CompileError.opError(OpError.new(
                    nd.csr,
                    op.op,
                    left,
                )));
            }

            nd.ty = if (entry.?.Binary.output) |out| out else left;
        },
        .Ternary => |trn| {
            _ = switch (inferExprType(cmp, trn.cond)) {
                .Success => |res| res,
                .Error => |err| return InferResult.err(err),
            };

            const ifT = switch (inferExprType(cmp, trn.ifTrue)) {
                .Success => |res| res,
                .Error => |err| return InferResult.err(err),
            };

            const ifF = switch (inferExprType(cmp, trn.ifFalse)) {
                .Success => |res| res,
                .Error => |err| return InferResult.err(err),
            };

            nd.ty = if (ifT == ifF)
                ifT
            else
                cmp.typebook.getUnion(&.{ ifT, ifF });
        },
        .Call => |call| {
            const func = inferExprType(cmp, call.expr);
            if (func.getType() != .Success)
                return func;

            if (func.Success.getType() != .Function) {
                return InferResult.err(CompileError.genericError(
                    GenericError.new(
                        call.expr.csr,
                        "Invalid function call as expression is not a function",
                    ),
                ));
            }

            const funcTy = func.Success.Function;

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
                const res = inferExprType(cmp, arg);
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
        },
        else => nd.ty = cmp.typebook.getUnknown(),
    }

    return InferResult.success(nd.ty.?);
}

const InferTestCase = struct {
    expectedTy: ?Type.Type = null,
    check: ?fn (
        scope: *Scope,
        typebook: *TypeBook,
        res: InferResult,
    ) anyerror!void = null,
    setup: ?fn (
        scope: *Scope,
        typebook: *TypeBook,
    ) anyerror!void = null,

    pub fn run(
        self: InferTestCase,
        comptime nodeType: NodeType,
        nodeData: anytype,
    ) !void {
        const config = Config{};
        var backend = NopBackend.new();

        var compiler = Compiler.new(
            std.testing.allocator,
            &config,
            &backend.backend,
        );
        defer compiler.deinit();

        if (self.setup) |setup|
            try setup(compiler.scope, compiler.typebook);

        const nd = makeNode(
            std.testing.allocator,
            Cursor.new(6, 9),
            nodeType,
            nodeData,
        );
        defer std.testing.allocator.destroy(nd);

        const res = inferExprType(&compiler, nd);

        if (res.getType() != .Success and self.expectedTy != null)
            try res.Error.report(std.io.getStdErr().writer());

        if (self.expectedTy) |expectedTy| {
            try expectEqual(InferResult.Success, res.getType());
            try expectEqual(expectedTy, res.Success.getType());
            try expect(nd.ty != null);
            try expectEqual(expectedTy, nd.ty.?.getType());
        }

        if (self.check) |check|
            try check(compiler.scope, compiler.typebook, res);
    }
};

test "can infer type of int literal" {
    try (InferTestCase{
        .expectedTy = .Number,
    }).run(.Int, "1234");
}

test "can infer type of string literals" {
    try (InferTestCase{
        .expectedTy = .String,
    }).run(.String, "'a string'");
}

test "can infer type of template literals" {
    try (InferTestCase{
        .expectedTy = .String,
    }).run(.Template, "`a template`");
}

test "can infer type of booleans" {
    try (InferTestCase{
        .expectedTy = .Boolean,
    }).run(.True, {});

    try (InferTestCase{
        .expectedTy = .Boolean,
    }).run(.False, {});
}

test "can infer type of 'null'" {
    try (InferTestCase{
        .expectedTy = .Null,
    }).run(.Null, {});
}

test "can infer type of 'undefined'" {
    try (InferTestCase{
        .expectedTy = .Undefined,
    }).run(.Undefined, {});
}

test "can infer type of an identifier" {
    try (InferTestCase{
        .expectedTy = .String,
        .setup = (struct {
            fn setup(
                scope: *Scope,
                typebook: *TypeBook,
            ) anyerror!void {
                scope.put(
                    "aVariable",
                    typebook.getString(),
                    false,
                    Cursor.new(0, 0),
                );
            }
        }).setup,
    }).run(.Ident, "aVariable");
}

test "can infer type of a homogeneous ternary expression" {
    const alloc = std.testing.allocator;
    const csr = Cursor.new(0, 0);

    const cond = makeNode(alloc, csr, .True, {});
    const ifTrue = makeNode(alloc, csr, .Int, "1");
    const ifFalse = makeNode(alloc, csr, .Int, "2");

    defer alloc.destroy(cond);
    defer alloc.destroy(ifTrue);
    defer alloc.destroy(ifFalse);

    try (InferTestCase{
        .expectedTy = .Number,
    }).run(.Ternary, node.Ternary{
        .cond = cond,
        .ifTrue = ifTrue,
        .ifFalse = ifFalse,
    });
}

test "can infer type of a non-homogeneous ternary expression" {
    const alloc = std.testing.allocator;
    const csr = Cursor.new(0, 0);

    const cond = makeNode(alloc, csr, .True, {});
    const ifTrue = makeNode(alloc, csr, .Int, "1");
    const ifFalse = makeNode(alloc, csr, .String, "'hello world'");

    defer alloc.destroy(cond);
    defer alloc.destroy(ifTrue);
    defer alloc.destroy(ifFalse);

    try (InferTestCase{
        .check = (struct {
            fn check(
                scope: *Scope,
                typebook: *TypeBook,
                res: InferResult,
            ) anyerror!void {
                _ = scope;

                const expectedTy = typebook.getUnion(&.{
                    typebook.getNumber(),
                    typebook.getString(),
                });

                try expectEqual(InferResult.Variant.Success, res.getType());
                try expectEqual(expectedTy, res.Success);
            }
        }).check,
    }).run(.Ternary, node.Ternary{
        .cond = cond,
        .ifTrue = ifTrue,
        .ifFalse = ifFalse,
    });
}

test "can infer type of function call with no arguments" {
    const alloc = std.testing.allocator;

    const func = makeNode(alloc, Cursor.new(0, 0), .Ident, "aFunction");
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
                    typebook.getFunction(typebook.getBoolean(), &[_]Type.Ptr{}),
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

    const func = makeNode(alloc, Cursor.new(0, 0), .Ident, "aFunction");
    defer alloc.destroy(func);

    const arg1 = makeNode(alloc, Cursor.new(0, 0), .Int, "34");
    const arg2 = makeNode(alloc, Cursor.new(0, 0), .String, "a string");
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

    const func = makeNode(alloc, Cursor.new(0, 0), .Ident, "aFunction");
    defer alloc.destroy(func);

    const arg = makeNode(alloc, Cursor.new(0, 0), .Int, "34");
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

                try expectEqual(InferResult.Variant.Error, res.getType());

                const err = res.Error;
                try expectEqual(CompileError.Type.GenericError, err.getType());
                try expectEqualStrings(
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

    const func = makeNode(alloc, Cursor.new(0, 0), .Ident, "aFunction");
    defer alloc.destroy(func);

    const arg = makeNode(alloc, Cursor.new(0, 0), .Int, "34");
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
                    typebook.getFunction(typebook.getBoolean(), &[_]Type.Ptr{
                        typebook.getString(),
                    }),
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

                try expectEqual(InferResult.Variant.Error, res.getType());

                const err = res.Error;
                try expectEqual(CompileError.Type.TypeError, err.getType());
                try expectEqual(err.TypeError.valueTy, typebook.getNumber());
                try expectEqual(err.TypeError.targetTy, typebook.getString());
            }
        }).check,
    }).run(.Call, .{
        .expr = func,
        .args = args,
    });
}
