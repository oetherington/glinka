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

pub fn inferObjectType(
    cmp: *Compiler,
    nd: node.Node,
    ctx: *const InferContext,
    obj: node.Object,
) InferResult {
    const subCtx = InferContext.none(ctx);

    // TODO: Refactor this to avoid allocation
    var members = allocate.alloc(
        cmp.alloc,
        Type.InterfaceType.Member,
        obj.items.len,
    );
    defer cmp.alloc.free(members);

    for (obj.items) |prop, index| {
        const name = prop.getName();
        switch (inferExprType(cmp, prop.value, &subCtx)) {
            .Success => |ty| members[index] = Type.InterfaceType.Member{
                .name = name,
                .ty = ty,
            },
            .Error => return InferResult.err(CompileError.genericError(
                GenericError.new(
                    nd.csr,
                    cmp.fmt(
                        "Object property '{s}' has an invalid type",
                        .{name},
                    ),
                ),
            )),
        }
    }

    nd.ty = cmp.typebook.getInterface(members);
    return InferResult.success(nd.ty.?);
}

test "can infer type of an object literal" {
    const nodes = [_]node.Node{
        node.makeNode(std.testing.allocator, Cursor.new(1, 1), .String, "'a'"),
        node.makeNode(std.testing.allocator, Cursor.new(2, 1), .String, "'1'"),
        node.makeNode(std.testing.allocator, Cursor.new(3, 1), .String, "'b'"),
        node.makeNode(std.testing.allocator, Cursor.new(4, 1), .Int, "2"),
    };

    defer for (nodes) |nd|
        std.testing.allocator.destroy(nd);

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

                try std.testing.expectEqual(
                    Type.Type.Interface,
                    res.Success.getType(),
                );
                const members = res.Success.Interface.members;
                try std.testing.expectEqual(@intCast(usize, 2), members.len);
                try std.testing.expectEqualStrings("a", members[0].name);
                try std.testing.expectEqual(
                    Type.Type.String,
                    members[0].ty.getType(),
                );
                try std.testing.expectEqualStrings("b", members[1].name);
                try std.testing.expectEqual(
                    Type.Type.Number,
                    members[1].ty.getType(),
                );
            }
        }).check,
    }).run(.Object, node.Object{
        .items = &[_]node.ObjectProperty{
            node.ObjectProperty.new(nodes[0], nodes[1]),
            node.ObjectProperty.new(nodes[2], nodes[3]),
        },
    });
}
