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
const node = @import("../../common/node.zig");
const Node = node.Node;
const Cursor = @import("../../common/cursor.zig").Cursor;
const Backend = @import("../../common/backend.zig").Backend;
const JsBackend = @import("js_backend.zig").JsBackend;

pub fn emitCond(self: *JsBackend, cond: node.If) Backend.Error!void {
    for (cond.branches.items) |branch, index| {
        try if (index == 0)
            self.out.print("if (", .{})
        else
            self.out.print(" else if (", .{});

        try self.emitExpr(branch.cond);

        try self.out.print(") ", .{});

        // TODO: Emit block
    }

    if (cond.elseBranch) |branch| {
        try self.out.print(" else ", .{});

        _ = branch;

        // TODO: Emit block
    }

    try self.out.print("\n", .{});
}
