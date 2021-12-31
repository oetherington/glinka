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
const Decl = @import("decl.zig").Decl;
const nodeImp = @import("../node.zig");
const Node = nodeImp.Node;
const makeNode = nodeImp.makeNode;

pub const For = struct {
    pub const Clause = union(Clause.Type) {
        pub const Type = enum {
            CStyle,
            Each,
        };

        pub const CStyleClause = struct {
            pre: Node,
            cond: Node,
            post: Node,
        };

        pub const EachClause = struct {
            pub const Variant = enum {
                Of,
                In,

                pub fn toString(self: Variant) []const u8 {
                    return switch (self) {
                        .Of => "of",
                        .In => "in",
                    };
                }
            };

            scoping: Decl.Scoping,
            variant: Variant,
            name: []const u8,
            expr: Node,
        };

        CStyle: CStyleClause,
        Each: EachClause,

        pub fn getType(self: Clause) Clause.Type {
            return @as(Clause.Type, self);
        }

        pub fn dump(
            self: Clause,
            writer: anytype,
            indent: usize,
        ) !void {
            try putInd(writer, indent, "{s}:\n", .{@tagName(self)});

            switch (self) {
                .CStyle => |cs| {
                    try cs.pre.dumpIndented(writer, indent + 2);
                    try cs.cond.dumpIndented(writer, indent + 2);
                    try cs.post.dumpIndented(writer, indent + 2);
                },
                .Each => |each| {
                    try putInd(writer, indent + 2, "{s}\n", .{
                        @tagName(each.scoping),
                    });
                    try putInd(writer, indent + 2, "{s}\n", .{each.name});
                    try putInd(writer, indent + 2, "{s}\n", .{
                        @tagName(each.variant),
                    });
                    try each.expr.dumpIndented(writer, indent + 2);
                },
            }
        }
    };

    clause: Clause,
    body: Node,

    pub fn new(clause: Clause, body: Node) For {
        return For{
            .clause = clause,
            .body = body,
        };
    }

    pub fn getType(self: For) Clause.Type {
        return self.clause.getType();
    }

    pub fn dump(
        self: For,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "For:\n", .{});
        try self.clause.dump(writer, indent + 2);
        try putInd(writer, indent + 2, "Body:\n", .{});
        try self.body.dumpIndented(writer, indent + 4);
    }
};

test "can convert For.Clause.EachClause.Variant to string" {
    try expectEqualStrings("of", For.Clause.EachClause.Variant.Of.toString());
    try expectEqualStrings("in", For.Clause.EachClause.Variant.In.toString());
}

test "can dump a CStyle For" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(4, 1), .Int, "4"),
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "2"),
        makeNode(std.testing.allocator, Cursor.new(3, 1), .Int, "3"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(For, .For){
        .value = For.new(For.Clause{
            .CStyle = .{
                .pre = nodes[1],
                .cond = nodes[2],
                .post = nodes[3],
            },
        }, nodes[0]),
        .expected = 
        \\For:
        \\  CStyle:
        \\    Int Node (1:1)
        \\      Int: "1"
        \\    Int Node (2:1)
        \\      Int: "2"
        \\    Int Node (3:1)
        \\      Int: "3"
        \\  Body:
        \\    Int Node (4:1)
        \\      Int: "4"
        \\
        ,
    }).run();
}

test "can dump a For Each" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(4, 1), .Int, "4"),
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Ident, "anArray"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(For, .For){
        .value = For.new(For.Clause{
            .Each = .{
                .scoping = .Const,
                .variant = .Of,
                .name = "i",
                .expr = nodes[1],
            },
        }, nodes[0]),
        .expected = 
        \\For:
        \\  Each:
        \\    Const
        \\    i
        \\    Of
        \\    Ident Node (1:1)
        \\      Ident: "anArray"
        \\  Body:
        \\    Int Node (4:1)
        \\      Int: "4"
        \\
        ,
    }).run();
}
