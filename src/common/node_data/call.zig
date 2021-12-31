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
const NodeList = nodeImp.NodeList;
const makeNode = nodeImp.makeNode;

pub const Call = struct {
    expr: Node,
    args: NodeList,

    pub fn new(expr: Node, args: NodeList) Call {
        return Call{
            .expr = expr,
            .args = args,
        };
    }

    pub fn dump(
        self: Call,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "Call:\n", .{});
        try putInd(writer, indent + 2, "Function:\n", .{});
        try self.expr.dumpIndented(writer, indent + 4);
        try putInd(writer, indent + 2, "Args:\n", .{});
        for (self.args.items) |arg|
            try arg.dumpIndented(writer, indent + 4);
    }
};

test "can dump a Call" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "2"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(Call, .Call){
        .value = Call.new(nodes[0], NodeList{ .items = &[_]Node{nodes[1]} }),
        .expected = 
        \\Call:
        \\  Function:
        \\    Int Node (1:1)
        \\      Int: "1"
        \\  Args:
        \\    Int Node (2:1)
        \\      Int: "2"
        \\
        ,
    }).run();
}
