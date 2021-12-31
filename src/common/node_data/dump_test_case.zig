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
const WriteContext = @import("../writer.zig").WriteContext;
const nodeImp = @import("../node.zig");
const NodeType = nodeImp.NodeType;
const NodeData = nodeImp.NodeData;

pub fn DumpTestCase(comptime T: type, comptime nodeType: NodeType) type {
    return struct {
        value: T,
        expected: []const u8,

        pub fn run(self: @This()) !void {
            const ctx = try WriteContext(.{}).new(std.testing.allocator);
            defer ctx.deinit();

            const data = @unionInit(NodeData, @tagName(nodeType), self.value);

            try data.dump(ctx.writer(), 0);

            const str = try ctx.toString();
            defer ctx.freeString(str);

            try std.testing.expectEqualStrings(self.expected, str);
        }
    };
}
