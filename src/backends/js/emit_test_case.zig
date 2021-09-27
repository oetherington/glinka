// glinka
// Copyright (C) 2021 Ollie Etherington
// <www.etherington.xyz>
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
const expectEqualStrings = std.testing.expectEqualStrings;
const Allocator = std.mem.Allocator;
const Cursor = @import("../../common/cursor.zig").Cursor;
const node = @import("../../common/node.zig");
const Node = node.Node;
const makeNode = node.makeNode;
const JsBackend = @import("js_backend.zig").JsBackend;

pub const EmitTestCase = struct {
    inputNode: Node,
    expectedOutput: []const u8,
    cleanup: ?fn (alloc: *Allocator, nd: Node) void = null,

    pub fn run(self: EmitTestCase) !void {
        var backend = try JsBackend.new(std.testing.allocator);
        defer backend.deinit();

        try backend.backend.processNode(self.inputNode);

        const str = try backend.toString();
        defer backend.freeString(str);

        try expectEqualStrings(self.expectedOutput, str);

        if (self.cleanup) |cleanup|
            cleanup(std.testing.allocator, self.inputNode);

        std.testing.allocator.destroy(self.inputNode);
    }

    pub fn makeNode(comptime ty: node.NodeType, data: anytype) Node {
        return node.makeNode(
            std.testing.allocator,
            Cursor.new(0, 0),
            ty,
            data,
        );
    }
};
