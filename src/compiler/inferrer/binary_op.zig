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
const CompileError = @import("../errors/compile_error.zig").CompileError;
const AssignError = @import("../errors/assign_error.zig").AssignError;
const OpError = @import("../errors/op_error.zig").OpError;
const node = @import("../../common/node.zig");
const InferResult = @import("infer_result.zig").InferResult;
const InferContext = @import("infer_context.zig").InferContext;
const InferTestCase = @import("infer_test_case.zig").InferTestCase;
const inferExprType = @import("inferrer.zig").inferExprType;

pub fn inferBinaryOpType(
    cmp: *Compiler,
    nd: node.Node,
    ctx: *const InferContext,
    op: node.BinaryOp,
) InferResult {
    const subCtx = InferContext.none(ctx);

    const left = switch (inferExprType(cmp, op.left, &subCtx)) {
        .Success => |res| res,
        .Error => |err| return InferResult.err(err),
    };

    const right = switch (inferExprType(cmp, op.right, &subCtx)) {
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
    std.debug.assert(entry == null or entry.?.getType() == .Binary);

    if (entry == null or !left.isAssignableTo(entry.?.Binary.input)) {
        return InferResult.err(CompileError.opError(OpError.new(
            nd.csr,
            op.op,
            left,
        )));
    }

    nd.ty = if (entry.?.Binary.output) |out| out else left;
    return InferResult.success(nd.ty.?);
}

test "can infer type of binary op expressions" {
    const int = node.makeNode(
        std.testing.allocator,
        Cursor.new(0, 0),
        .Int,
        "3",
    );
    defer std.testing.allocator.destroy(int);

    try (InferTestCase{
        .expectedTy = .Number,
    }).run(.BinaryOp, node.BinaryOp{
        .op = .Add,
        .left = int,
        .right = int,
    });
}
