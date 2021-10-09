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

pub fn emitSwitch(self: *JsBackend, sw: node.Switch) Backend.Error!void {
    try self.out.print("switch (", .{});
    try self.emitExpr(sw.expr);
    try self.out.print(") {{\n", .{});

    for (sw.cases.items) |case| {
        try self.out.print("case ", .{});
        try self.emitExpr(case.value);
        try self.out.print(":\n", .{});

        for (case.stmts.items) |stmt|
            try self.emitNode(stmt);
    }

    if (sw.default) |default| {
        try self.out.print("default:\n", .{});
        for (default.items) |stmt|
            try self.emitNode(stmt);
    }

    try self.out.print("}}\n", .{});
}

test "JsBackend can emit 'switch' statement" {
    const alloc = std.testing.allocator;

    const expr = EmitTestCase.makeNode(.Ident, "a");
    defer alloc.destroy(expr);

    const cases = node.Switch.CaseList{
        .items = &[_]node.Switch.Case{
            node.Switch.Case{
                .value = EmitTestCase.makeNode(.Int, "1"),
                .stmts = node.NodeList{
                    .items = &[_]Node{
                        EmitTestCase.makeNode(.Return, null),
                    },
                },
            },
            node.Switch.Case{
                .value = EmitTestCase.makeNode(.Int, "2"),
                .stmts = node.NodeList{
                    .items = &[_]Node{
                        EmitTestCase.makeNode(.Null, {}),
                        EmitTestCase.makeNode(.Break, null),
                    },
                },
            },
        },
    };
    defer alloc.destroy(cases.items[0].value);
    defer alloc.destroy(cases.items[0].stmts.items[0]);
    defer alloc.destroy(cases.items[1].value);
    defer alloc.destroy(cases.items[1].stmts.items[0]);
    defer alloc.destroy(cases.items[1].stmts.items[1]);

    const default = node.NodeList{
        .items = &[_]Node{
            EmitTestCase.makeNode(.Break, null),
        },
    };
    defer alloc.destroy(default.items[0]);

    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Switch, node.Switch{
            .expr = expr,
            .cases = cases,
            .default = default,
        }),
        .expectedOutput = 
        \\switch (a) {
        \\case 1:
        \\return;
        \\case 2:
        \\null;
        \\break;
        \\default:
        \\break;
        \\}
        \\
        ,
    }).run();
}
