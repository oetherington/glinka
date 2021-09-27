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
const node = @import("../../common/node.zig");
const Node = node.Node;
const Cursor = @import("../../common/cursor.zig").Cursor;
const Backend = @import("../../common/backend.zig").Backend;
const JsBackend = @import("js_backend.zig").JsBackend;
const EmitTestCase = @import("emit_test_case.zig").EmitTestCase;

pub fn emitCond(self: *JsBackend, cond: node.If) Backend.Error!void {
    for (cond.branches.items) |branch, index| {
        try if (index == 0)
            self.out.print("if (", .{})
        else
            self.out.print("else if (", .{});
        try self.emitExpr(branch.cond);
        try self.out.print(") ", .{});
        try self.emitNode(branch.ifTrue);
    }

    if (cond.elseBranch) |branch| {
        try self.out.print("else ", .{});
        try self.emitNode(branch);
    }
}

test "JsBackend can emit 'if' statement" {
    const alloc = std.testing.allocator;

    var branches = node.If.BranchList{};
    defer branches.deinit(alloc);

    try branches.append(alloc, node.If.Branch{
        .cond = EmitTestCase.makeNode(.True, {}),
        .ifTrue = EmitTestCase.makeNode(.Null, {}),
    });
    defer alloc.destroy(branches.items[0].cond);
    defer alloc.destroy(branches.items[0].ifTrue);

    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.If, node.If{
            .branches = branches,
            .elseBranch = null,
        }),
        .expectedOutput = "if (true) null;\n",
    }).run();
}

test "JsBackend can emit 'if' statement with 'else if'" {
    const alloc = std.testing.allocator;

    var branches = node.If.BranchList{};
    defer branches.deinit(alloc);

    try branches.append(alloc, node.If.Branch{
        .cond = EmitTestCase.makeNode(.True, {}),
        .ifTrue = EmitTestCase.makeNode(.Null, {}),
    });
    defer alloc.destroy(branches.items[0].cond);
    defer alloc.destroy(branches.items[0].ifTrue);

    try branches.append(alloc, node.If.Branch{
        .cond = EmitTestCase.makeNode(.False, {}),
        .ifTrue = EmitTestCase.makeNode(.Undefined, {}),
    });
    defer alloc.destroy(branches.items[1].cond);
    defer alloc.destroy(branches.items[1].ifTrue);

    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.If, node.If{
            .branches = branches,
            .elseBranch = null,
        }),
        .expectedOutput = "if (true) null;\nelse if (false) undefined;\n",
    }).run();
}

test "JsBackend can emit 'if' statement with 'else'" {
    const alloc = std.testing.allocator;

    var branches = node.If.BranchList{};
    defer branches.deinit(alloc);

    try branches.append(alloc, node.If.Branch{
        .cond = EmitTestCase.makeNode(.True, {}),
        .ifTrue = EmitTestCase.makeNode(.Null, {}),
    });
    defer alloc.destroy(branches.items[0].cond);
    defer alloc.destroy(branches.items[0].ifTrue);

    const elseBranch = EmitTestCase.makeNode(.Undefined, {});
    defer alloc.destroy(elseBranch);

    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.If, node.If{
            .branches = branches,
            .elseBranch = elseBranch,
        }),
        .expectedOutput = "if (true) null;\nelse undefined;\n",
    }).run();
}

test "JsBackend can emit 'if' statement with 'else if' and 'else'" {
    const alloc = std.testing.allocator;

    var branches = node.If.BranchList{};
    defer branches.deinit(alloc);

    try branches.append(alloc, node.If.Branch{
        .cond = EmitTestCase.makeNode(.True, {}),
        .ifTrue = EmitTestCase.makeNode(.Null, {}),
    });
    defer alloc.destroy(branches.items[0].cond);
    defer alloc.destroy(branches.items[0].ifTrue);

    try branches.append(alloc, node.If.Branch{
        .cond = EmitTestCase.makeNode(.False, {}),
        .ifTrue = EmitTestCase.makeNode(.String, "'a'"),
    });
    defer alloc.destroy(branches.items[1].cond);
    defer alloc.destroy(branches.items[1].ifTrue);

    const elseBranch = EmitTestCase.makeNode(.Int, "1");
    defer alloc.destroy(elseBranch);

    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.If, node.If{
            .branches = branches,
            .elseBranch = elseBranch,
        }),
        .expectedOutput = "if (true) null;\nelse if (false) 'a';\nelse 1;\n",
    }).run();
}
