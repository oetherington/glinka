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
const makeNode = nodeImp.makeNode;

pub const If = struct {
    pub const Branch = struct {
        cond: Node,
        ifTrue: Node,

        pub fn eql(a: Branch, b: Branch) bool {
            return genericEql.eql(a, b);
        }
    };

    pub const BranchList = std.ArrayListUnmanaged(Branch);

    branches: BranchList,
    elseBranch: ?Node,

    pub fn new(branches: BranchList, elseBranch: ?Node) If {
        return If{
            .branches = branches,
            .elseBranch = elseBranch,
        };
    }

    pub fn dump(
        self: If,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "If:\n", .{});

        for (self.branches.items) |item| {
            try putInd(writer, indent + 2, "Cond:\n", .{});
            try item.cond.dumpIndented(writer, indent + 4);
            try putInd(writer, indent + 2, "Branch:\n", .{});
            try item.ifTrue.dumpIndented(writer, indent + 4);
        }

        if (self.elseBranch) |branch| {
            try putInd(writer, indent + 2, "Else:\n", .{});
            try branch.dumpIndented(writer, indent + 4);
        }
    }
};

test "can check If.Branch equality" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "2"),
        makeNode(std.testing.allocator, Cursor.new(3, 1), .Int, "3"),
        makeNode(std.testing.allocator, Cursor.new(4, 1), .Int, "4"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    const a = If.Branch{ .cond = nodes[0], .ifTrue = nodes[1] };
    const b = If.Branch{ .cond = nodes[0], .ifTrue = nodes[1] };
    const c = If.Branch{ .cond = nodes[2], .ifTrue = nodes[3] };

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

test "can dump an If" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "2"),
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "3"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    var branches = If.BranchList{};
    defer branches.deinit(std.testing.allocator);

    try branches.append(std.testing.allocator, If.Branch{
        .cond = nodes[0],
        .ifTrue = nodes[1],
    });

    try (DumpTestCase(If, .If){
        .value = If.new(branches, nodes[2]),
        .expected = 
        \\If:
        \\  Cond:
        \\    Int Node (1:1)
        \\      Int: "1"
        \\  Branch:
        \\    Int Node (1:1)
        \\      Int: "2"
        \\  Else:
        \\    Int Node (1:1)
        \\      Int: "3"
        \\
        ,
    }).run();
}
