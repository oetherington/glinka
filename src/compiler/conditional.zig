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

pub fn processConditional(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == .If);

    const cond = nd.data.If;

    for (cond.branches.items) |branch| {
        _ = cmp.inferExprType(branch.cond);
        cmp.processNode(branch.ifTrue);
    }

    if (cond.elseBranch) |branch| {
        cmp.processNode(branch);
    }
}

test "can compile simple 'if' statement" {
    try (CompilerTestCase{
        .code = "if (true) var a = 6;",
    }).run();
}

test "can compile 'if' statement with 'else'" {
    try (CompilerTestCase{
        .code = "if (true) var a = 6; else var b = 7;",
    }).run();
}

test "can compile 'if' statement with 'else if'" {
    try (CompilerTestCase{
        .code = "if (true) var a = 6; else if (false) var b = 7;",
    }).run();
}

test "can compile 'if' statement with multiple 'else if'" {
    try (CompilerTestCase{
        .code = 
        \\if (true) var a = 6;
        \\else if (false) var b = 7;
        \\else if (3) var c = 8;
        \\else if (4) var d = 9;
        ,
    }).run();
}

test "can compile 'if' statement with multiple 'else if' and 'else'" {
    try (CompilerTestCase{
        .code = 
        \\if (true) var a = 6;
        \\else if (false) var b = 7;
        \\else if (3) var c = 8;
        \\else if (4) var d = 9;
        \\else var e = 10;
        ,
    }).run();
}
