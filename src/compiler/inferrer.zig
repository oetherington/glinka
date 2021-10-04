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
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Scope = @import("scope.zig").Scope;
const TypeBook = @import("typebook.zig").TypeBook;
const Type = @import("../common/types/type.zig").Type;
const CompileError = @import("errors/compile_error.zig").CompileError;
const OpError = @import("errors/op_error.zig").OpError;
const AssignError = @import("errors/assign_error.zig").AssignError;
const GenericError = @import("errors/generic_error.zig").GenericError;
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

pub fn inferExprType(scope: *Scope, typebook: *TypeBook, nd: Node) InferResult {
    const ty = switch (nd.data) {
        .Int => typebook.getNumber(),
        .String, .Template => typebook.getString(),
        .True, .False => typebook.getBoolean(),
        .Null => typebook.getNull(),
        .Undefined => typebook.getUndefined(),
        .Ident => |ident| if (scope.get(ident)) |sym|
            sym.ty
        else
            typebook.getUndefined(),
        .PrefixOp, .PostfixOp => |op| {
            const expr = switch (inferExprType(scope, typebook, op.expr)) {
                .Success => |res| res,
                .Error => |err| return InferResult.err(err),
            };

            // We assume it's unary, otherwise the Node wouldn't have parsed
            if (typebook.getOpEntry(op.op)) |entry|
                if (expr.isAssignableTo(entry.Unary.input))
                    return InferResult.success(
                        if (entry.Unary.output) |out| out else expr,
                    );

            return InferResult.err(CompileError.opError(OpError.new(
                nd.csr,
                op.op,
                expr,
            )));
        },
        .BinaryOp => |op| {
            const left = switch (inferExprType(scope, typebook, op.left)) {
                .Success => |res| res,
                .Error => |err| return InferResult.err(err),
            };

            const right = switch (inferExprType(scope, typebook, op.right)) {
                .Success => |res| res,
                .Error => |err| return InferResult.err(err),
            };

            if (!right.isAssignableTo(left))
                return InferResult.err(CompileError.assignError(
                    AssignError.new(nd.csr, left, right),
                ));

            // We assume it's binary, otherwise the Node wouldn't have parsed
            if (typebook.getOpEntry(op.op)) |entry|
                if (left.isAssignableTo(entry.Binary.input))
                    return InferResult.success(
                        if (entry.Binary.output) |out| out else left,
                    );

            return InferResult.err(CompileError.opError(OpError.new(
                nd.csr,
                op.op,
                left,
            )));
        },
        .Ternary => |trn| {
            _ = switch (inferExprType(scope, typebook, trn.cond)) {
                .Success => |res| res,
                .Error => |err| return InferResult.err(err),
            };

            const ifT = switch (inferExprType(scope, typebook, trn.ifTrue)) {
                .Success => |res| res,
                .Error => |err| return InferResult.err(err),
            };

            const ifF = switch (inferExprType(scope, typebook, trn.ifFalse)) {
                .Success => |res| res,
                .Error => |err| return InferResult.err(err),
            };

            const ty = if (ifT == ifF)
                ifT
            else
                typebook.getUnion(&.{ ifT, ifF });

            return InferResult.success(ty);
        },
        .Call => |call| {
            const func = inferExprType(scope, typebook, call.expr);
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

            // if (funcTy.args.len != call.args.len) {
            // return InferResult.err(CompileError.genericError(
            // GenericError.new(
            // call.expr.csr,
            // cmp.fmt(
            // "Function expected {d} arguments but found {d}",
            // .{ funcTy.args.len, call.args.len },
            // ),
            // ),
            // ));
            // }

            return InferResult.success(funcTy.ret);
        },
        else => typebook.getUnknown(),
    };

    return InferResult.success(ty);
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
        const scope = Scope.new(std.testing.allocator, null);
        defer scope.deinit();

        var typebook = TypeBook.new(std.testing.allocator);
        defer typebook.deinit();

        if (self.setup) |setup|
            try setup(scope, typebook);

        const nd = makeNode(
            std.testing.allocator,
            Cursor.new(6, 9),
            nodeType,
            nodeData,
        );
        defer std.testing.allocator.destroy(nd);

        const res = inferExprType(scope, typebook, nd);

        if (self.expectedTy) |expectedTy| {
            try expectEqual(InferResult.Success, res.getType());
            try expectEqual(expectedTy, res.Success.getType());
        }

        if (self.check) |check|
            try check(scope, typebook, res);
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

const builtinMap = std.ComptimeStringMap(
    fn (self: *TypeBook) Type.Ptr,
    .{
        .{ "number", TypeBook.getNumber },
        .{ "string", TypeBook.getString },
        .{ "boolean", TypeBook.getBoolean },
        .{ "void", TypeBook.getVoid },
        .{ "any", TypeBook.getAny },
    },
);

pub fn findType(scope: *Scope, typebook: *TypeBook, nd: Node) ?Type.Ptr {
    _ = scope;

    switch (nd.data) {
        .TypeName => |name| {
            if (builtinMap.get(name)) |func| {
                return func(typebook);
            } else {
                // TODO: Lookup in scope if not builtin
                return null;
            }
        },
        .UnionType => |un| {
            const alloc = scope.getAllocator();
            const tys = allocate.alloc(alloc, Type.Ptr, un.items.len);
            defer alloc.free(tys);

            for (un.items) |item, index| {
                if (findType(scope, typebook, item)) |ty|
                    tys[index] = ty
                else
                    return null;
            }

            return typebook.getUnion(tys);
        },
        else => return null,
    }
}

const FindTypeTestCase = struct {
    inputNode: Node,
    check: fn (ty: ?Type.Ptr) anyerror!void,

    pub fn run(self: FindTypeTestCase) !void {
        const scope = Scope.new(std.testing.allocator, null);
        defer scope.deinit();

        var typebook = TypeBook.new(std.testing.allocator);
        defer typebook.deinit();

        defer std.testing.allocator.destroy(self.inputNode);

        const ty = findType(scope, typebook, self.inputNode);
        try self.check(ty);
    }
};

test "can lookup builtin types" {
    try (FindTypeTestCase{
        .inputNode = makeNode(
            std.testing.allocator,
            Cursor.new(11, 4),
            .TypeName,
            "number",
        ),
        .check = (struct {
            fn check(ty: ?Type.Ptr) anyerror!void {
                try expect(ty != null);
                try expectEqual(Type.Type.Number, ty.?.getType());
            }
        }).check,
    }).run();
}

test "can lookup union types" {
    const alloc = std.testing.allocator;
    const csr = Cursor.new(6, 7);

    const string = makeNode(alloc, csr, .TypeName, "string");
    const number = makeNode(alloc, csr, .TypeName, "number");
    defer alloc.destroy(string);
    defer alloc.destroy(number);

    var list = node.NodeList{};
    defer list.deinit(alloc);
    try list.append(alloc, string);
    try list.append(alloc, number);

    try (FindTypeTestCase{
        .inputNode = makeNode(alloc, csr, .UnionType, list),
        .check = (struct {
            fn check(ty: ?Type.Ptr) anyerror!void {
                try expectEqual(Type.Type.Union, ty.?.getType());

                const tys: []Type.Ptr = ty.?.Union.tys;
                try expectEqual(@intCast(usize, 2), tys.len);
                try expectEqual(Type.Type.Number, tys[0].getType());
                try expectEqual(Type.Type.String, tys[1].getType());
            }
        }).check,
    }).run();
}
