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
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const Cursor = @import("../cursor.zig").Cursor;
const Token = @import("../token.zig").Token;
const putInd = @import("indenter.zig").putInd;
const DumpTestCase = @import("dump_test_case.zig").DumpTestCase;
const nodeImp = @import("../node.zig");
const Node = nodeImp.Node;
const makeNode = nodeImp.makeNode;

pub const Ternary = struct {
    cond: Node,
    ifTrue: Node,
    ifFalse: Node,

    pub fn new(cond: Node, ifTrue: Node, ifFalse: Node) Ternary {
        return Ternary{
            .cond = cond,
            .ifTrue = ifTrue,
            .ifFalse = ifFalse,
        };
    }

    pub fn dump(
        self: Ternary,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "Ternary Expression\n", .{});
        try self.cond.dumpIndented(writer, indent + 2);
        try self.ifTrue.dumpIndented(writer, indent + 2);
        try self.ifFalse.dumpIndented(writer, indent + 2);
    }
};

test "can dump a Ternary" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "2"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "3"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(Ternary, .Ternary){
        .value = Ternary.new(nodes[0], nodes[1], nodes[2]),
        .expected = 
        \\Ternary Expression
        \\  Int Node (1:1)
        \\    Int: "1"
        \\  Int Node (1:1)
        \\    Int: "2"
        \\  Int Node (2:1)
        \\    Int: "3"
        \\
        ,
    }).run();
}
