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
const Compiler = @import("compiler.zig").Compiler;
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const Type = @import("types/type.zig").Type;
const GenericError = @import("generic_error.zig").GenericError;
const CompileError = @import("compile_error.zig").CompileError;
const CompilerTestCase = @import("compiler_test_case.zig").CompilerTestCase;

pub fn processWhile(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == .While);

    const loop = nd.data.While;

    _ = cmp.inferExprType(loop.cond);
    cmp.processNode(loop.body);
}

test "can compile 'while' statements" {
    try (CompilerTestCase{
        .code = "while (true) var a = 6;",
    }).run();
}

pub fn processDo(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == .Do);

    const loop = nd.data.Do;

    cmp.processNode(loop.body);
    _ = cmp.inferExprType(loop.cond);
}

test "can compile 'do' statements" {
    try (CompilerTestCase{
        .code = "do var x = 3; while (true);",
    }).run();
}
