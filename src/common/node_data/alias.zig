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

pub const Alias = struct {
    name: []const u8,
    value: Node,

    pub fn new(name: []const u8, value: Node) Alias {
        return Alias{
            .name = name,
            .value = value,
        };
    }

    pub fn dump(
        self: Alias,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "Alias: '{s}'\n", .{self.name});
        try self.value.dumpIndented(writer, indent + 2);
    }
};

test "can dump an Alias" {
    const node = makeNode(
        std.testing.allocator,
        Cursor.new(1, 1),
        .TypeName,
        "number",
    );
    defer std.testing.allocator.destroy(node);

    try (DumpTestCase(Alias, .Alias){
        .value = Alias.new("AnAlias", node),
        .expected = 
        \\Alias: 'AnAlias'
        \\  TypeName Node (1:1)
        \\    TypeName: "number"
        \\
        ,
    }).run();
}
