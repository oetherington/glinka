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

pub const Labelled = struct {
    label: []const u8,
    stmt: Node,

    pub fn new(label: []const u8, stmt: Node) Labelled {
        return Labelled{
            .label = label,
            .stmt = stmt,
        };
    }

    pub fn dump(
        self: Labelled,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "Labelled \"{s}\":\n", .{self.label});
        try self.stmt.dumpIndented(writer, indent + 2);
    }
};

test "can dump a Labelled" {
    const node = makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1");
    defer std.testing.allocator.destroy(node);

    try (DumpTestCase(Labelled, .Labelled){
        .value = Labelled.new("aLabel", node),
        .expected = 
        \\Labelled "aLabel":
        \\  Int Node (1:1)
        \\    Int: "1"
        \\
        ,
    }).run();
}
