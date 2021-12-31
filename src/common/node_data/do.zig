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

pub const Do = struct {
    body: Node,
    cond: Node,

    pub fn new(body: Node, cond: Node) Do {
        return Do{
            .body = body,
            .cond = cond,
        };
    }

    pub fn dump(
        self: Do,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "Do:\n", .{});
        try putInd(writer, indent + 2, "Body:\n", .{});
        try self.body.dumpIndented(writer, indent + 4);
        try putInd(writer, indent + 2, "Condition:\n", .{});
        try self.cond.dumpIndented(writer, indent + 4);
    }
};

test "can dump a Do" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "2"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(Do, .Do){
        .value = Do.new(nodes[0], nodes[1]),
        .expected = 
        \\Do:
        \\  Body:
        \\    Int Node (1:1)
        \\      Int: "1"
        \\  Condition:
        \\    Int Node (2:1)
        \\      Int: "2"
        \\
        ,
    }).run();
}
