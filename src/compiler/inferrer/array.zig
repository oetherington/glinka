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
const node = @import("../../common/node.zig");
const InferResult = @import("infer_result.zig").InferResult;
const InferContext = @import("infer_context.zig").InferContext;
const InferTestCase = @import("infer_test_case.zig").InferTestCase;
const inferExprType = @import("inferrer.zig").inferExprType;

pub fn inferArrayType(
    cmp: *Compiler,
    nd: node.Node,
    ctx: *const InferContext,
    arr: node.NodeList,
) InferResult {
    if (arr.items.len == 0) {
        nd.ty = cmp.typebook.getArray(cmp.typebook.getUnknown());
    } else {
        const subCtx = InferContext.none(ctx);

        var res = inferExprType(cmp, arr.items[0], &subCtx);
        if (res.getType() != .Success)
            return res;

        var subtype = res.Success;

        for (arr.items[1..]) |item| {
            res = inferExprType(cmp, item, &subCtx);
            if (res.getType() != .Success)
                return res;

            subtype = cmp.typebook.combine(subtype, res.Success);
        }

        nd.ty = cmp.typebook.getArray(subtype);
    }

    return InferResult.success(nd.ty.?);
}

test "can infer type of an empty array" {
    const items = node.NodeList{ .items = &[_]node.Node{} };
    try (InferTestCase{
        .expectedTy = .Array,
    }).run(.Array, items);
}

test "can infer type of a homogeneous array" {
    const alloc = std.testing.allocator;
    const csr = Cursor.new(0, 0);

    const items = node.NodeList{ .items = &[_]node.Node{
        node.makeNode(alloc, csr, .Int, "1"),
        node.makeNode(alloc, csr, .Int, "2"),
    } };
    defer alloc.destroy(items.items[0]);
    defer alloc.destroy(items.items[1]);

    try (InferTestCase{
        .check = (struct {
            fn check(
                scope: *Scope,
                typebook: *TypeBook,
                res: InferResult,
            ) anyerror!void {
                _ = scope;
                _ = typebook;

                try InferTestCase.expectSuccess(res);

                const arr = res.Success;
                try std.testing.expectEqual(Type.Type.Array, arr.getType());
                try std.testing.expectEqual(
                    Type.Type.Number,
                    arr.Array.subtype.getType(),
                );
            }
        }).check,
    }).run(.Array, items);
}

test "can infer type of an inhomogeneous array" {
    const alloc = std.testing.allocator;
    const csr = Cursor.new(0, 0);

    const items = node.NodeList{ .items = &[_]node.Node{
        node.makeNode(alloc, csr, .Int, "1"),
        node.makeNode(alloc, csr, .String, "'a'"),
    } };
    defer alloc.destroy(items.items[0]);
    defer alloc.destroy(items.items[1]);

    try (InferTestCase{
        .check = (struct {
            fn check(
                scope: *Scope,
                typebook: *TypeBook,
                res: InferResult,
            ) anyerror!void {
                _ = scope;
                _ = typebook;

                try InferTestCase.expectSuccess(res);

                const arr = res.Success;
                try std.testing.expectEqual(Type.Type.Array, arr.getType());

                const sub = arr.Array.subtype;
                try std.testing.expectEqual(Type.Type.Union, sub.getType());
                try std.testing.expectEqual(
                    Type.Type.Number,
                    sub.Union.tys[0].getType(),
                );
                try std.testing.expectEqual(
                    Type.Type.String,
                    sub.Union.tys[1].getType(),
                );
            }
        }).check,
    }).run(.Array, items);
}
