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
const Compiler = @import("../compiler.zig").Compiler;
const Scope = @import("../scope.zig").Scope;
const TypeBook = @import("../typebook.zig").TypeBook;
const node = @import("../../common/node.zig");
const InferResult = @import("infer_result.zig").InferResult;
const InferContext = @import("infer_context.zig").InferContext;
const InferTestCase = @import("infer_test_case.zig").InferTestCase;
const inferExprType = @import("inferrer.zig").inferExprType;

pub fn inferTernaryType(
    cmp: *Compiler,
    nd: node.Node,
    ctx: InferContext,
    trn: node.Ternary,
) InferResult {
    _ = ctx; // TODO

    _ = switch (inferExprType(cmp, trn.cond, .None)) {
        .Success => |res| res,
        .Error => |err| return InferResult.err(err),
    };

    const ifT = switch (inferExprType(cmp, trn.ifTrue, .None)) {
        .Success => |res| res,
        .Error => |err| return InferResult.err(err),
    };

    const ifF = switch (inferExprType(cmp, trn.ifFalse, .None)) {
        .Success => |res| res,
        .Error => |err| return InferResult.err(err),
    };

    nd.ty = if (ifT == ifF)
        ifT
    else
        cmp.typebook.getUnion(&.{ ifT, ifF });

    return InferResult.success(nd.ty.?);
}

test "can infer type of a homogeneous ternary expression" {
    const alloc = std.testing.allocator;
    const csr = Cursor.new(0, 0);

    const cond = node.makeNode(alloc, csr, .True, {});
    const ifTrue = node.makeNode(alloc, csr, .Int, "1");
    const ifFalse = node.makeNode(alloc, csr, .Int, "2");

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

    const cond = node.makeNode(alloc, csr, .True, {});
    const ifTrue = node.makeNode(alloc, csr, .Int, "1");
    const ifFalse = node.makeNode(alloc, csr, .String, "'hello world'");

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

                try std.testing.expectEqual(
                    InferResult.Variant.Success,
                    res.getType(),
                );
                try std.testing.expectEqual(expectedTy, res.Success);
            }
        }).check,
    }).run(.Ternary, node.Ternary{
        .cond = cond,
        .ifTrue = ifTrue,
        .ifFalse = ifFalse,
    });
}
