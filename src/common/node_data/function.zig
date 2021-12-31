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

pub const Function = struct {
    pub const Arg = struct {
        csr: Cursor,
        name: []const u8,
        ty: ?Node,

        pub fn eql(a: Arg, b: Arg) bool {
            return genericEql.eql(a, b);
        }
    };

    pub const ArgList = std.ArrayListUnmanaged(Arg);

    isArrow: bool,
    name: ?[]const u8,
    retTy: ?Node,
    args: ArgList,
    body: Node,

    pub fn new(
        isArrow: bool,
        name: ?[]const u8,
        retTy: ?Node,
        args: ArgList,
        body: Node,
    ) Function {
        return Function{
            .isArrow = isArrow,
            .name = name,
            .retTy = retTy,
            .args = args,
            .body = body,
        };
    }

    pub fn dump(
        self: Function,
        writer: anytype,
        indent: usize,
    ) !void {
        const arrow = if (self.isArrow) "Arrow " else "";
        const name = if (self.name) |name| name else "<anonymous>";

        try putInd(writer, indent, "{s}Function: {s}\n", .{ arrow, name });

        if (self.retTy) |retTy|
            try retTy.dumpIndented(writer, indent + 2);

        try putInd(writer, indent, "Arguments:\n", .{});
        for (self.args.items) |arg| {
            try putInd(writer, indent + 2, "'{s}'\n", .{arg.name});
            if (arg.ty) |ty|
                try ty.dumpIndented(writer, indent + 4);
        }

        try putInd(writer, indent, "Body:\n", .{});
        try self.body.dumpIndented(writer, indent + 2);
    }
};

test "can check Function.Argument equality" {
    const node = makeNode(
        std.testing.allocator,
        Cursor.new(1, 5),
        .TypeName,
        "number",
    );
    defer std.testing.allocator.destroy(node);

    const a = Function.Arg{ .csr = Cursor.new(1, 1), .name = "a", .ty = node };
    const b = Function.Arg{ .csr = Cursor.new(1, 1), .name = "a", .ty = node };
    const c = Function.Arg{ .csr = Cursor.new(2, 1), .name = "b", .ty = null };

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

test "can dump a Function" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .TypeName, "number"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .TypeName, "number"),
        makeNode(std.testing.allocator, Cursor.new(3, 1), .Int, "1"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    var args = Function.ArgList{};
    defer args.deinit(std.testing.allocator);

    try args.append(std.testing.allocator, Function.Arg{
        .csr = Cursor.new(1, 2),
        .name = "anArg",
        .ty = nodes[0],
    });

    try (DumpTestCase(Function, .Function){
        .value = Function.new(false, "aFunction", nodes[1], args, nodes[2]),
        .expected = 
        \\Function: aFunction
        \\  TypeName Node (2:1)
        \\    TypeName: "number"
        \\Arguments:
        \\  'anArg'
        \\    TypeName Node (1:1)
        \\      TypeName: "number"
        \\Body:
        \\  Int Node (3:1)
        \\    Int: "1"
        \\
        ,
    }).run();
}
