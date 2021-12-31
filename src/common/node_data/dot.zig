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

pub const Dot = struct {
    expr: Node,
    ident: []const u8,

    pub fn new(expr: Node, ident: []const u8) Dot {
        return Dot{
            .expr = expr,
            .ident = ident,
        };
    }

    pub fn dump(
        self: Dot,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "Dot \"{s}\":\n", .{self.ident});
        try self.expr.dumpIndented(writer, indent + 2);
    }
};

test "can dump a Dot" {
    const node = makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1");
    defer std.testing.allocator.destroy(node);

    try (DumpTestCase(Dot, .Dot){
        .value = Dot.new(node, "aProperty"),
        .expected = 
        \\Dot "aProperty":
        \\  Int Node (1:1)
        \\    Int: "1"
        \\
        ,
    }).run();
}
