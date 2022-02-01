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
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const Cursor = @import("../../common/cursor.zig").Cursor;
const node = @import("../../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Compiler = @import("../compiler.zig").Compiler;
const Scope = @import("../scope.zig").Scope;
const TypeBook = @import("../typebook.zig").TypeBook;
const Type = @import("../../common/types/type.zig").Type;
const CompileError = @import("../errors/compile_error.zig").CompileError;
const OpError = @import("../errors/op_error.zig").OpError;
const AssignError = @import("../errors/assign_error.zig").AssignError;
const GenericError = @import("../errors/generic_error.zig").GenericError;
const TypeError = @import("../errors/type_error.zig").TypeError;
const InferResult = @import("infer_result.zig").InferResult;
const InferContext = @import("infer_context.zig").InferContext;
const InferTestCase = @import("infer_test_case.zig").InferTestCase;
const inferPrimaryExprType = @import("primary.zig").inferPrimaryExprType;
const inferUnaryOpType = @import("unary_op.zig").inferUnaryOpType;
const inferBinaryOpType = @import("binary_op.zig").inferBinaryOpType;
const inferTernaryType = @import("ternary.zig").inferTernaryType;
const inferCallType = @import("call.zig").inferCallType;
const inferArrayType = @import("array.zig").inferArrayType;
const inferArrayAccessType = @import("array_access.zig").inferArrayAccessType;
const inferDotType = @import("dot.zig").inferDotType;
const inferObjectType = @import("object.zig").inferObjectType;
const inferNewType = @import("new.zig").inferNewType;
const allocate = @import("../../common/allocate.zig");

pub fn inferExprType(cmp: *Compiler, nd: Node, ctx: InferContext) InferResult {
    return switch (nd.data) {
        .Int => inferPrimaryExprType(nd, cmp.typebook.getNumber()),
        .Float => inferPrimaryExprType(nd, cmp.typebook.getNumber()),
        .String,
        .Template,
        => inferPrimaryExprType(nd, cmp.typebook.getString()),
        .True,
        .False,
        => inferPrimaryExprType(nd, cmp.typebook.getBoolean()),
        .Null => inferPrimaryExprType(nd, cmp.typebook.getNull()),
        .Undefined => inferPrimaryExprType(nd, cmp.typebook.getUndefined()),
        .Ident => |ident| inferPrimaryExprType(
            nd,
            if (cmp.scope.get(ident)) |sym|
                sym.ty
            else
                cmp.typebook.getUndefined(),
        ),
        .PrefixOp,
        .PostfixOp,
        => |op| inferUnaryOpType(cmp, nd, ctx, op),
        .BinaryOp => |op| inferBinaryOpType(cmp, nd, ctx, op),
        .Ternary => |trn| inferTernaryType(cmp, nd, ctx, trn),
        .Call => |call| inferCallType(cmp, nd, ctx, call),
        .Array => |arr| inferArrayType(cmp, nd, ctx, arr),
        .ArrayAccess => |access| inferArrayAccessType(cmp, nd, ctx, access),
        .Dot => |dot| inferDotType(cmp, nd, ctx, dot),
        .Object => |obj| inferObjectType(cmp, nd, ctx, obj),
        .New => |new| inferNewType(cmp, nd, ctx, new),
        else => std.debug.panic(
            "Unhandled node type in inferExprType: {?}\n",
            .{nd.getType()},
        ),
    };
}
