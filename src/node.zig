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
const expectEqualSlices = std.testing.expectEqualSlices;
const Allocator = std.mem.Allocator;
const Cursor = @import("cursor.zig").Cursor;
const genericEql = @import("generic_eql.zig");

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
    name: []const u8,
    ty: ?Node,
    value: ?Node,

    pub fn new(name: []const u8, ty: ?Node, value: ?Node) Decl {
        return Decl{
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
        try putInd(writer, indent, "Decl \"{s}\"\n", .{self.name});

        if (self.ty) |ty|
            try ty.dumpIndented(writer, indent + 2);

        if (self.value) |value|
            try value.dumpIndented(writer, indent + 2);
    }
};

pub const NodeType = enum(u8) {
    Var,
    Let,
    Const,
    Int,
    Ident,
    True,
    False,
    Null,
    Undefined,
    TypeName,
};

pub const NodeData = union(NodeType) {
    Var: Decl,
    Let: Decl,
    Const: Decl,
    Int: []const u8,
    Ident: []const u8,
    True: void,
    False: void,
    Null: void,
    Undefined: void,
    TypeName: []const u8,

    pub fn dump(
        self: NodeData,
        writer: anytype,
        indent: usize,
    ) std.os.WriteError!void {
        switch (self) {
            .Var, .Let, .Const => |decl| try decl.dump(writer, indent),
            .Int => |s| try putInd(writer, indent, "Int: {s}\n", .{s}),
            .Ident => |s| try putInd(writer, indent, "Identifier: {s}\n", .{s}),
            .True, .False, .Null, .Undefined => try putInd("{s}", .{@tagName(self)}),
            .TypeName => |s| try putInd(writer, indent, "TypeName \"{s}\"\n", .{s}),
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
        NodeType.Var,
        Decl.new(name, null, null),
    );
    defer std.testing.allocator.destroy(node);
    try expectEqual(node.getType(), NodeType.Var);
    try expectEqualSlices(u8, name, node.data.Var.name);
}

test "can compare Nodes for equality" {
    const name = "aVarName";

    const a = try makeNode(
        std.testing.allocator,
        Cursor.new(0, 0),
        NodeType.Var,
        Decl.new(name, null, null),
    );

    const b = try makeNode(
        std.testing.allocator,
        Cursor.new(0, 0),
        NodeType.Var,
        Decl.new(name, null, null),
    );

    const c = try makeNode(
        std.testing.allocator,
        Cursor.new(1, 1),
        NodeType.Let,
        Decl.new(name, null, null),
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
