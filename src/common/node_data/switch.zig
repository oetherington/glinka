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
const genericEql = @import("../generic_eql.zig");
const Cursor = @import("../cursor.zig").Cursor;
const Token = @import("../token.zig").Token;
const putInd = @import("indenter.zig").putInd;
const DumpTestCase = @import("dump_test_case.zig").DumpTestCase;
const nodeImp = @import("../node.zig");
const Node = nodeImp.Node;
const NodeList = nodeImp.NodeList;
const makeNode = nodeImp.makeNode;

pub const Switch = struct {
    pub const Case = struct {
        value: Node,
        stmts: NodeList,

        pub fn eql(a: Case, b: Case) bool {
            return genericEql.eql(a, b);
        }
    };

    pub const CaseList = std.ArrayListUnmanaged(Case);

    expr: Node,
    cases: CaseList,
    default: ?NodeList,

    pub fn new(expr: Node, cases: CaseList, default: ?NodeList) Switch {
        return Switch{
            .expr = expr,
            .cases = cases,
            .default = default,
        };
    }

    pub fn dump(
        self: Switch,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "Switch:\n", .{});
        try self.expr.dumpIndented(writer, indent + 2);

        for (self.cases.items) |item| {
            try putInd(writer, indent + 2, "Case:\n", .{});
            try item.value.dumpIndented(writer, indent + 4);
            for (item.stmts.items) |stmt|
                try stmt.dumpIndented(writer, indent + 4);
        }

        if (self.default) |default| {
            try putInd(writer, indent + 2, "Default:\n", .{});
            for (default.items) |stmt|
                try stmt.dumpIndented(writer, indent + 4);
        }
    }
};

test "can compare Switch.Case equality" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "2"),
        makeNode(std.testing.allocator, Cursor.new(3, 1), .Int, "3"),
        makeNode(std.testing.allocator, Cursor.new(4, 1), .Int, "4"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    const a = Switch.Case{
        .value = nodes[0],
        .stmts = NodeList{ .items = &[_]Node{nodes[1]} },
    };
    const b = Switch.Case{
        .value = nodes[0],
        .stmts = NodeList{ .items = &[_]Node{nodes[1]} },
    };
    const c = Switch.Case{
        .value = nodes[2],
        .stmts = NodeList{ .items = &[_]Node{nodes[3]} },
    };

    try expect(a.eql(a));
    try expect(a.eql(b));
    try expect(!a.eql(c));
    try expect(b.eql(a));
    try expect(b.eql(b));
    try expect(!b.eql(c));
    try expect(!c.eql(a));
    try expect(!c.eql(b));
    try expect(c.eql(c));
}

test "can dump a Switch" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "2"),
        makeNode(std.testing.allocator, Cursor.new(3, 1), .Int, "3"),
        makeNode(std.testing.allocator, Cursor.new(4, 1), .Int, "4"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(Switch, .Switch){
        .value = Switch.new(
            nodes[0],
            Switch.CaseList{
                .items = &[_]Switch.Case{Switch.Case{
                    .value = nodes[1],
                    .stmts = NodeList{ .items = &[_]Node{nodes[2]} },
                }},
            },
            NodeList{ .items = &[_]Node{nodes[3]} },
        ),
        .expected = 
        \\Switch:
        \\  Int Node (1:1)
        \\    Int: "1"
        \\  Case:
        \\    Int Node (2:1)
        \\      Int: "2"
        \\    Int Node (3:1)
        \\      Int: "3"
        \\  Default:
        \\    Int Node (4:1)
        \\      Int: "4"
        \\
        ,
    }).run();
}
