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

pub const Try = struct {
    pub const Catch = struct {
        name: []const u8,
        block: Node,

        pub fn eql(a: Catch, b: Catch) bool {
            return genericEql.eql(a, b);
        }
    };

    pub const CatchList = std.ArrayListUnmanaged(Catch);

    tryBlock: Node,
    catchBlocks: CatchList,
    finallyBlock: ?Node,

    pub fn new(
        tryBlock: Node,
        catchBlocks: CatchList,
        finallyBlock: ?Node,
    ) Try {
        return Try{
            .tryBlock = tryBlock,
            .catchBlocks = catchBlocks,
            .finallyBlock = finallyBlock,
        };
    }

    pub fn dump(
        self: Try,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "Try:\n", .{});
        try self.tryBlock.dumpIndented(writer, indent + 2);

        for (self.catchBlocks.items) |item| {
            try putInd(writer, indent, "Catch \"{s}\":\n", .{item.name});
            try item.block.dumpIndented(writer, indent + 2);
        }

        if (self.finallyBlock) |finally| {
            try putInd(writer, indent, "Finally:\n", .{});
            try finally.dumpIndented(writer, indent + 2);
        }
    }
};

test "can compare Try.Catch equality" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "2"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    const a = Try.Catch{ .name = "a", .block = nodes[0] };
    const b = Try.Catch{ .name = "a", .block = nodes[0] };
    const c = Try.Catch{ .name = "b", .block = nodes[1] };

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

test "can dump a Try" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "2"),
        makeNode(std.testing.allocator, Cursor.new(3, 1), .Int, "3"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(Try, .Try){
        .value = Try.new(nodes[0], Try.CatchList{
            .items = &[_]Try.Catch{Try.Catch{
                .name = "anException",
                .block = nodes[1],
            }},
        }, nodes[2]),
        .expected = 
        \\Try:
        \\  Int Node (1:1)
        \\    Int: "1"
        \\Catch "anException":
        \\  Int Node (2:1)
        \\    Int: "2"
        \\Finally:
        \\  Int Node (3:1)
        \\    Int: "3"
        \\
        ,
    }).run();
}
