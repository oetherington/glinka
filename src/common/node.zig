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
const expectError = std.testing.expectError;
const Allocator = std.mem.Allocator;
const Token = @import("token.zig").Token;
const Cursor = @import("cursor.zig").Cursor;
const genericEql = @import("generic_eql.zig");
const Type = @import("types/type.zig").Type;
const allocate = @import("allocate.zig");

const putInd = @import("node_data/indenter.zig").putInd;
const DumpTestCase = @import("node_data/dump_test_case.zig").DumpTestCase;

pub const NodeList = std.ArrayListUnmanaged(Node);

const objectImp = @import("node_data/object.zig");
pub const Object = objectImp.Object;
pub const ObjectProperty = objectImp.ObjectProperty;

const interface = @import("node_data/interface.zig");
pub const InterfaceTypeMember = interface.InterfaceTypeMember;
pub const InterfaceTypeMemberList = interface.InterfaceTypeMemberList;
pub const InterfaceType = interface.InterfaceType;

pub const Decl = @import("node_data/decl.zig").Decl;

pub const UnaryOp = @import("node_data/unary_op.zig").UnaryOp;

pub const BinaryOp = @import("node_data/binary_op.zig").BinaryOp;

pub const Ternary = @import("node_data/ternary.zig").Ternary;

pub const Alias = @import("node_data/alias.zig").Alias;

pub const Function = @import("node_data/function.zig").Function;

pub const If = @import("node_data/if.zig").If;

pub const For = @import("node_data/for.zig").For;

pub const While = @import("node_data/while.zig").While;

pub const Do = @import("node_data/do.zig").Do;

pub const Labelled = @import("node_data/labelled.zig").Labelled;

pub const Try = @import("node_data/try.zig").Try;

pub const Switch = @import("node_data/switch.zig").Switch;

pub const Dot = @import("node_data/dot.zig").Dot;

pub const ArrayAccess = @import("node_data/array_access.zig").ArrayAccess;

pub const Call = @import("node_data/call.zig").Call;

pub const NodeType = enum {
    EOF,
    Program,
    Decl,
    Int,
    Float,
    Ident,
    String,
    Template,
    Comma,
    Array,
    Object,
    True,
    False,
    Null,
    Undefined,
    This,
    PostfixOp,
    PrefixOp,
    BinaryOp,
    Ternary,
    TypeName,
    UnionType,
    ArrayType,
    InterfaceType,
    Alias,
    Function,
    Block,
    If,
    Switch,
    For,
    While,
    Do,
    Return,
    Break,
    Continue,
    Throw,
    Labelled,
    Try,
    Dot,
    ArrayAccess,
    Call,
};

pub const NodeData = union(NodeType) {
    EOF: void,
    Program: NodeList,
    Decl: Decl,
    Int: []const u8,
    Float: []const u8,
    Ident: []const u8,
    String: []const u8,
    Template: []const u8,
    Comma: NodeList,
    Array: NodeList,
    Object: Object,
    True: void,
    False: void,
    Null: void,
    Undefined: void,
    This: void,
    PostfixOp: UnaryOp,
    PrefixOp: UnaryOp,
    BinaryOp: BinaryOp,
    Ternary: Ternary,
    TypeName: []const u8,
    UnionType: NodeList,
    ArrayType: Node,
    InterfaceType: InterfaceType,
    Alias: Alias,
    Function: Function,
    Block: NodeList,
    If: If,
    Switch: Switch,
    For: For,
    While: While,
    Do: Do,
    Return: ?Node,
    Break: ?[]const u8,
    Continue: ?[]const u8,
    Throw: Node,
    Labelled: Labelled,
    Try: Try,
    Dot: Dot,
    ArrayAccess: ArrayAccess,
    Call: Call,

    pub fn dump(
        self: NodeData,
        writer: anytype,
        indent: usize,
    ) anyerror!void {
        switch (self) {
            .Decl => |decl| try decl.dump(writer, indent),
            .Int,
            .Float,
            .TypeName,
            .Ident,
            .String,
            .Template,
            => |s| try putInd(
                writer,
                indent,
                "{s}: \"{s}\"\n",
                .{ @tagName(self), s },
            ),
            .Program, .Comma, .UnionType, .Array, .Block => |list| {
                try putInd(writer, indent, "{s}\n", .{@tagName(self)});
                for (list.items) |item|
                    try item.dumpIndented(writer, indent + 2);
            },
            .Object => |object| {
                try putInd(writer, indent, "Object\n", .{});
                for (object.items) |item|
                    try item.dump(writer, indent + 2);
            },
            .EOF, .True, .False, .Null, .Undefined, .This => try putInd(
                writer,
                indent,
                "{s}\n",
                .{@tagName(self)},
            ),
            .PostfixOp, .PrefixOp => |unaryOp| {
                try putInd(writer, indent, "{s}\n", .{@tagName(self)});
                try unaryOp.dump(writer, indent + 2);
            },
            .Return => |ret| {
                try putInd(writer, indent, "Return\n", .{});
                if (ret) |expr|
                    try expr.dumpIndented(writer, indent + 2);
            },
            .Break, .Continue => |label| try putInd(
                writer,
                indent,
                "{s} \"{s}\"\n",
                .{ @tagName(self), if (label) |l| l else "" },
            ),
            .ArrayType, .Throw => |nd| {
                try putInd(writer, indent, "{s}\n", .{@tagName(self)});
                try nd.dumpIndented(writer, indent + 2);
            },
            .InterfaceType => |objTy| {
                try putInd(
                    writer,
                    indent,
                    "InterfaceType {s}\n",
                    .{if (objTy.name) |name| name else ""},
                );
                for (objTy.members.items) |member|
                    try member.dump(writer, indent + 2);
            },
            .BinaryOp => |binaryOp| try binaryOp.dump(writer, indent),
            .Ternary => |ternary| try ternary.dump(writer, indent),
            .Alias => |alias| try alias.dump(writer, indent),
            .Function => |func| try func.dump(writer, indent),
            .If => |stmt| try stmt.dump(writer, indent),
            .Switch => |stmt| try stmt.dump(writer, indent),
            .For => |loop| try loop.dump(writer, indent),
            .While => |loop| try loop.dump(writer, indent),
            .Do => |loop| try loop.dump(writer, indent),
            .Try => |t| try t.dump(writer, indent),
            .ArrayAccess => |aa| try aa.dump(writer, indent),
            .Dot => |dot| try dot.dump(writer, indent),
            .Call => |call| try call.dump(writer, indent),
            .Labelled => |labelled| try labelled.dump(writer, indent),
        }
    }

    pub fn getType(self: NodeData) NodeType {
        return @as(NodeType, self);
    }
};

test "can dump Nodes with NodeList data" {
    const node = makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1");
    defer std.testing.allocator.destroy(node);

    try (DumpTestCase(NodeList, .Program){
        .value = NodeList{ .items = &[_]Node{node} },
        .expected = 
        \\Program
        \\  Int Node (1:1)
        \\    Int: "1"
        \\
        ,
    }).run();
}

test "can dump Nodes with void data" {
    try (DumpTestCase(void, .True){
        .value = {},
        .expected = "True\n",
    }).run();
}

test "can dump Nodes with ?Node data" {
    const node = makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1");
    defer std.testing.allocator.destroy(node);

    try (DumpTestCase(?Node, .Return){
        .value = node,
        .expected = 
        \\Return
        \\  Int Node (1:1)
        \\    Int: "1"
        \\
        ,
    }).run();
}

test "can dump Nodes with ?[]const u8 data" {
    try (DumpTestCase(?[]const u8, .Break){
        .value = "aLabel",
        .expected = "Break \"aLabel\"\n",
    }).run();
}

test "can dump Nodes with Node data" {
    const node = makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1");
    defer std.testing.allocator.destroy(node);

    try (DumpTestCase(Node, .ArrayType){
        .value = node,
        .expected = 
        \\ArrayType
        \\  Int Node (1:1)
        \\    Int: "1"
        \\
        ,
    }).run();
}

pub const NodeImpl = struct {
    csr: Cursor,
    data: NodeData,
    ty: ?Type.Ptr = null,

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
    ) !void {
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
    alloc: Allocator,
    csr: Cursor,
    comptime ty: NodeType,
    data: anytype,
) Node {
    var n = allocate.create(alloc, NodeImpl);
    n.csr = csr;
    n.data = @unionInit(NodeData, @tagName(ty), data);
    return n;
}

test "can generically initialize Nodes with makeNode" {
    const name = "aVariableName";
    const node = makeNode(
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

    const a = makeNode(
        std.testing.allocator,
        Cursor.new(0, 0),
        NodeType.Decl,
        Decl.new(.Var, name, null, null),
    );

    const b = makeNode(
        std.testing.allocator,
        Cursor.new(0, 0),
        NodeType.Decl,
        Decl.new(.Var, name, null, null),
    );

    const c = makeNode(
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
