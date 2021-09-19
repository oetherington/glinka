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
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Scope = @import("scope.zig").Scope;
const Type = @import("types/type.zig").Type;
const TypeBook = @import("types/typebook.zig").TypeBook;
const CompileError = @import("compile_error.zig").CompileError;
const OpError = @import("op_error.zig").OpError;

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
    const implicitAnyError = @import("types/implicit_any_error.zig");
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

            // TODO check left == right
            std.debug.assert(left == right);

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
        else => typebook.getUnknown(),
    };

    return InferResult.success(ty);
}

fn inferTestCase(
    comptime nodeType: NodeType,
    nodeData: anytype,
    expectedType: Type.Type,
) !void {
    const scope = try Scope.new(std.testing.allocator, null);
    defer scope.deinit();

    var typebook = try TypeBook.new(std.testing.allocator);
    defer typebook.deinit();

    const nd = try makeNode(
        std.testing.allocator,
        Cursor.new(6, 9),
        nodeType,
        nodeData,
    );
    defer std.testing.allocator.destroy(nd);

    const ty = inferExprType(scope, typebook, nd);
    try expectEqual(InferResult.Success, ty.getType());
    try expectEqual(expectedType, ty.Success.getType());
}

test "can inter type of int literal" {
    try inferTestCase(.Int, "1234", .Number);
}

test "can inter type of string literals" {
    try inferTestCase(.String, "1234", .String);
    try inferTestCase(.Template, "1234", .String);
}

test "can inter type of boolean" {
    try inferTestCase(.True, {}, .Boolean);
    try inferTestCase(.False, {}, .Boolean);
}

test "can inter type of 'null'" {
    try inferTestCase(.Null, {}, .Null);
}

test "can inter type of 'undefined'" {
    try inferTestCase(.Undefined, {}, .Undefined);
}

test "can inter type of an identifier" {
    // TODO
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

pub fn findType(scope: *Scope, typebook: *TypeBook, nd: Node) !Type.Ptr {
    _ = scope;

    switch (nd.data) {
        .TypeName => |name| {
            if (builtinMap.get(name)) |func| {
                return func(typebook);
            } else {
                // TODO: Lookup in scope if not builtin
                return error.InvalidType;
            }
        },
        else => return error.InvalidType,
    }
}

test "can lookup builtin types" {
    const scope = try Scope.new(std.testing.allocator, null);
    defer scope.deinit();

    var typebook = try TypeBook.new(std.testing.allocator);
    defer typebook.deinit();

    const nd = try makeNode(
        std.testing.allocator,
        Cursor.new(11, 4),
        .TypeName,
        "number",
    );
    defer std.testing.allocator.destroy(nd);

    const ty = try findType(scope, typebook, nd);
    try expectEqual(Type.Type.Number, ty.getType());
}
