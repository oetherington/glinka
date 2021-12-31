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

pub const UnaryOp = struct {
    op: Token.Type,
    expr: Node,

    pub fn new(op: Token.Type, expr: Node) UnaryOp {
        return UnaryOp{
            .op = op,
            .expr = expr,
        };
    }

    pub fn dump(
        self: UnaryOp,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "{s} Unary Op\n", .{@tagName(self.op)});
        try self.expr.dumpIndented(writer, indent + 2);
    }
};

test "can dump a prefix UnaryOp" {
    const node = makeNode(std.testing.allocator, Cursor.new(1, 5), .Int, "1");
    defer std.testing.allocator.destroy(node);

    try (DumpTestCase(UnaryOp, .PrefixOp){
        .value = UnaryOp.new(.Sub, node),
        .expected = 
        \\PrefixOp
        \\  Sub Unary Op
        \\    Int Node (1:5)
        \\      Int: "1"
        \\
        ,
    }).run();
}

test "can dump a postfix UnaryOp" {
    const node = makeNode(std.testing.allocator, Cursor.new(1, 5), .Int, "1");
    defer std.testing.allocator.destroy(node);

    try (DumpTestCase(UnaryOp, .PostfixOp){
        .value = UnaryOp.new(.Sub, node),
        .expected = 
        \\PostfixOp
        \\  Sub Unary Op
        \\    Int Node (1:5)
        \\      Int: "1"
        \\
        ,
    }).run();
}
