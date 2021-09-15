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
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const Allocator = std.mem.Allocator;
const Token = @import("token.zig").Token;
const Cursor = @import("../common/cursor.zig").Cursor;
const genericEql = @import("../common/generic_eql.zig");

fn putInd(
    writer: anytype,
    indent: usize,
    comptime fmt: []const u8,
    args: anytype,
) std.os.WriteError!void {
    var i: usize = 0;
    while (i < indent) : (i += 1) {
        try writer.print(" ", .{});
    }

    try writer.print(fmt, args);
}

pub const Decl = struct {
    pub const Scoping = enum {
        Var,
        Let,
        Const,

        pub fn fromTokenType(tkn: Token.Type) !Scoping {
            return switch (tkn) {
                .Var => .Var,
                .Let => .Let,
                .Const => .Const,
            };
        }

        pub fn toString(self: Scoping) []const u8 {
            return switch (self) {
                .Var => "var",
                .Let => "let",
                .Const => "const",
            };
        }
    };

    scoping: Scoping,
    name: []const u8,
    ty: ?Node,
    value: ?Node,

    pub fn new(
        scoping: Scoping,
        name: []const u8,
        ty: ?Node,
        value: ?Node,
    ) Decl {
        return Decl{
            .scoping = scoping,
            .name = name,
            .ty = ty,
            .value = value,
        };
    }

    pub fn dump(
        self: Decl,
        writer: anytype,
        indent: usize,
    ) std.os.WriteError!void {
        try putInd(writer, indent, "{s} Decl \"{s}\"\n", .{
            @tagName(self.scoping),
            self.name,
        });

        if (self.ty) |ty|
            try ty.dumpIndented(writer, indent + 2);

        if (self.value) |value|
            try value.dumpIndented(writer, indent + 2);
    }
};

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
    ) std.os.WriteError!void {
        try putInd(writer, indent, "{s} Unary Op\n", .{@tagName(self.op)});
        try self.expr.dumpIndented(writer, indent + 2);
    }
};

pub const BinaryOp = struct {
    op: Token.Type,
    left: Node,
    right: Node,

    pub fn new(op: Token.Type, left: Node, right: Node) BinaryOp {
        return BinaryOp{
            .op = op,
            .left = left,
            .right = right,
        };
    }

    pub fn dump(
        self: BinaryOp,
        writer: anytype,
        indent: usize,
    ) std.os.WriteError!void {
        try putInd(writer, indent, "{s} Binary Op\n", .{@tagName(self.op)});
        try self.left.dumpIndented(writer, indent + 2);
        try self.right.dumpIndented(writer, indent + 2);
    }
};

pub const NodeType = enum(u8) {
    EOF,
    Decl,
    Int,
    Ident,
    String,
    Template,
    True,
    False,
    Null,
    Undefined,
    This,
    PostfixOp,
    PrefixOp,
    BinaryOp,
    TypeName,
};

pub const NodeData = union(NodeType) {
    EOF: void,
    Decl: Decl,
    Int: []const u8,
    Ident: []const u8,
    String: []const u8,
    Template: []const u8,
    True: void,
    False: void,
    Null: void,
    Undefined: void,
    This: void,
    PostfixOp: UnaryOp,
    PrefixOp: UnaryOp,
    BinaryOp: BinaryOp,
    TypeName: []const u8,

    pub fn dump(
        self: NodeData,
        writer: anytype,
        indent: usize,
    ) std.os.WriteError!void {
        switch (self) {
            .Decl => |decl| try decl.dump(writer, indent),
            .Int, .TypeName, .Ident, .String, .Template => |s| try putInd(
                writer,
                indent,
                "{s}: \"{s}\"\n",
                .{ @tagName(self), s },
            ),
            .EOF, .True, .False, .Null, .Undefined, .This => try putInd(
                writer,
                indent,
                "{s}\n",
                .{@tagName(self)},
            ),
            .PostfixOp, .PrefixOp => |unaryOp| {
                try putInd(writer, indent, "{s}\n", .{@tagName(self)});
                try unaryOp.dump(writer, indent);
            },
            .BinaryOp => |binaryOp| try binaryOp.dump(writer, indent),
        }
    }

    pub fn getType(self: NodeData) NodeType {
        return @as(NodeType, self);
    }
};

pub const NodeImpl = struct {
    csr: Cursor,
    data: NodeData,

    pub fn getType(self: Node) NodeType {
        return @as(NodeType, self.data);
    }

    pub fn eql(self: Node, other: ?Node) bool {
        if (other) |n|
            return genericEql.eql(self.*, n.*);
        return false;
    }

    pub fn dump(self: Node) void {
        const writer = std.io.getStdOut().writer();
        self.dumpIndented(writer, 0) catch unreachable;
    }

    pub fn dumpIndented(
        self: Node,
        writer: anytype,
        indent: usize,
    ) std.os.WriteError!void {
        try putInd(writer, indent, "{s} Node ({d}:{d})\n", .{
            @tagName(self.data),
            self.csr.ln,
            self.csr.ch,
        });

        try self.data.dump(writer, indent + 2);
    }
};

pub const Node = *NodeImpl;

pub fn makeNode(
    alloc: *Allocator,
    csr: Cursor,
    comptime ty: NodeType,
    data: anytype,
) Allocator.Error!Node {
    var n = try alloc.create(NodeImpl);
    n.csr = csr;
    n.data = @unionInit(NodeData, @tagName(ty), data);
    return n;
}

test "can initialize a var node" {
    const name = "aVariableName";
    const node = try makeNode(
        std.testing.allocator,
        Cursor.new(0, 0),
        NodeType.Decl,
        Decl.new(.Var, name, null, null),
    );
    defer std.testing.allocator.destroy(node);
    try expectEqual(node.getType(), NodeType.Decl);
    try expectEqual(node.data.Decl.scoping, .Var);
    try expectEqualStrings(name, node.data.Decl.name);
}

test "can compare Nodes for equality" {
    const name = "aVarName";

    const a = try makeNode(
        std.testing.allocator,
        Cursor.new(0, 0),
        NodeType.Decl,
        Decl.new(.Var, name, null, null),
    );

    const b = try makeNode(
        std.testing.allocator,
        Cursor.new(0, 0),
        NodeType.Decl,
        Decl.new(.Var, name, null, null),
    );

    const c = try makeNode(
        std.testing.allocator,
        Cursor.new(1, 1),
        NodeType.Decl,
        Decl.new(.Var, name, null, null),
    );

    defer std.testing.allocator.destroy(a);
    defer std.testing.allocator.destroy(b);
    defer std.testing.allocator.destroy(c);

    try expect(a.eql(b));
    try expect(b.eql(a));
    try expect(!a.eql(c));
    try expect(!b.eql(c));
    try expect(!a.eql(null));
}
