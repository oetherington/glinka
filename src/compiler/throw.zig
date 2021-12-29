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
const Compiler = @import("compiler.zig").Compiler;
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const Type = @import("../common/types/type.zig").Type;
const TypeError = @import("errors/type_error.zig").TypeError;
const RedefinitionError = @import("errors/redefinition_error.zig").RedefinitionError;
const GenericError = @import("errors/generic_error.zig").GenericError;
const CompileError = @import("errors/compile_error.zig").CompileError;
const CompilerTestCase = @import("compiler_test_case.zig").CompilerTestCase;
const allocate = @import("../common/allocate.zig");

pub fn processThrow(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == NodeType.Throw);
    _ = cmp.inferExprType(nd.data.Throw);
}

test "can compile a 'throw' statement" {
    try (CompilerTestCase{
        .code = "throw false;",
    }).run();
}

pub fn processTry(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == NodeType.Try);

    const data = nd.data.Try;

    cmp.scope.ctx = .Try;
    cmp.processNode(data.tryBlock);
    cmp.scope.ctx = null;

    cmp.scope.ctx = .Catch;
    for (data.catchBlocks.items) |catchBlock| {
        cmp.pushScope();
        cmp.scope.ctx = .Catch;

        cmp.scope.put(
            catchBlock.name,
            cmp.typebook.getAny(),
            false,
            nd.csr,
        );

        cmp.processNode(catchBlock.block);

        cmp.popScope();
    }

    if (data.finallyBlock) |finallyBlock| {
        cmp.scope.ctx = .Finally;
        cmp.processNode(finallyBlock);
        cmp.scope.ctx = null;
    }
}

test "can compile a 'try/catch/finally' statement" {
    try (CompilerTestCase{
        .code = "try { var a = 6; } catch (e) { true; } finally { null; }",
    }).run();
}
