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

pub const NodeList = std.ArrayListUnmanaged(Node);

pub const Object = std.ArrayListUnmanaged(ObjectProperty);

pub const ObjectProperty = struct {
    key: Node,
    value: Node,

    pub fn new(key: Node, value: Node) ObjectProperty {
        return ObjectProperty{
            .key = key,
            .value = value,
        };
    }

    pub fn dump(
        self: ObjectProperty,
        writer: anytype,
        indent: usize,
    ) std.os.WriteError!void {
        try putInd(writer, indent, "Property\n", .{});
        try self.key.dumpIndented(writer, indent + 2);
        try self.value.dumpIndented(writer, indent + 2);
    }

    pub fn eql(self: ObjectProperty, other: ObjectProperty) bool {
        return genericEql.eql(self, other);
    }
};

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

pub const Ternary = struct {
    cond: Node,
    ifTrue: Node,
    ifFalse: Node,

    pub fn new(cond: Node, ifTrue: Node, ifFalse: Node) Ternary {
        return Ternary{
            .cond = cond,
            .ifTrue = ifTrue,
            .ifFalse = ifFalse,
        };
    }

    pub fn dump(
        self: Ternary,
        writer: anytype,
        indent: usize,
    ) std.os.WriteError!void {
        try putInd(writer, indent, "Ternary Expression\n", .{});
        try self.cond.dumpIndented(writer, indent + 2);
        try self.ifTrue.dumpIndented(writer, indent + 2);
        try self.ifFalse.dumpIndented(writer, indent + 2);
    }
};

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

    pub fn dump(
        self: Function,
        writer: anytype,
        indent: usize,
    ) std.os.WriteError!void {
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

pub const If = struct {
    pub const Branch = struct {
        cond: Node,
        ifTrue: Node,

        pub fn eql(a: Branch, b: Branch) bool {
            return genericEql.eql(a, b);
        }
    };

    pub const BranchList = std.ArrayListUnmanaged(Branch);

    branches: BranchList,
    elseBranch: ?Node,

    pub fn dump(
        self: If,
        writer: anytype,
        indent: usize,
    ) std.os.WriteError!void {
        try putInd(writer, indent, "If:\n", .{});

        for (self.branches.items) |item| {
            try putInd(writer, indent + 2, "Cond:\n", .{});
            try item.cond.dumpIndented(writer, indent + 4);
            try putInd(writer, indent + 2, "Branch:\n", .{});
            try item.ifTrue.dumpIndented(writer, indent + 4);
        }

        if (self.elseBranch) |branch| {
            try putInd(writer, indent + 2, "Else:\n", .{});
            try branch.dumpIndented(writer, indent + 4);
        }
    }
};

pub const While = struct {
    cond: Node,
    body: Node,

    pub fn dump(
        self: While,
        writer: anytype,
        indent: usize,
    ) std.os.WriteError!void {
        try putInd(writer, indent, "While:\n", .{});
        try self.cond.dumpIndented(writer, indent + 2);
        try self.body.dumpIndented(writer, indent + 2);
    }
};

pub const Do = struct {
    body: Node,
    cond: Node,

    pub fn dump(
        self: Do,
        writer: anytype,
        indent: usize,
    ) std.os.WriteError!void {
        try putInd(writer, indent, "Do:\n", .{});
        try self.body.dumpIndented(writer, indent + 2);
        try self.cond.dumpIndented(writer, indent + 2);
    }
};

pub const Labelled = struct {
    label: []const u8,
    stmt: Node,

    pub fn dump(
        self: Labelled,
        writer: anytype,
        indent: usize,
    ) std.os.WriteError!void {
        try putInd(writer, indent, "Labelled \"{s}\":\n", .{self.label});
        try self.stmt.dumpIndented(writer, indent + 2);
    }
};

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

    pub fn dump(
        self: Try,
        writer: anytype,
        indent: usize,
    ) std.os.WriteError!void {
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

pub const Dot = struct {
    expr: Node,
    ident: []const u8,

    pub fn dump(
        self: Dot,
        writer: anytype,
        indent: usize,
    ) std.os.WriteError!void {
        try putInd(writer, indent, "Dot \"{s}\":\n", .{self.ident});
        try self.expr.dumpIndented(writer, indent + 2);
    }
};

pub const ArrayAccess = struct {
    expr: Node,
    index: Node,

    pub fn dump(
        self: ArrayAccess,
        writer: anytype,
        indent: usize,
    ) std.os.WriteError!void {
        try putInd(writer, indent, "Array Access:\n", .{});
        try self.expr.dumpIndented(writer, indent + 2);
        try self.index.dumpIndented(writer, indent + 2);
    }
};

pub const Call = struct {
    expr: Node,
    args: NodeList,

    pub fn dump(
        self: Call,
        writer: anytype,
        indent: usize,
    ) std.os.WriteError!void {
        try putInd(writer, indent, "Call:\n", .{});
        try self.expr.dumpIndented(writer, indent + 2);

        try putInd(writer, indent, "Args:\n", .{});
        for (self.args.items) |arg|
            try arg.dumpIndented(writer, indent + 4);
    }
};

pub const NodeType = enum {
    EOF,
    Program,
    Decl,
    Int,
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
    Function,
    Block,
    If,
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
    Function: Function,
    Block: NodeList,
    If: If,
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
    ) std.os.WriteError!void {
        switch (self) {
            .Decl => |decl| try decl.dump(writer, indent),
            .Int, .TypeName, .Ident, .String, .Template => |s| try putInd(
                writer,
                indent,
                "{s}: \"{s}\"\n",
                .{ @tagName(self), s },
            ),
            .Program, .Comma, .Array, .Block => |list| {
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
                try unaryOp.dump(writer, indent);
            },
            .Return => |ret| {
                try putInd(writer, indent, "Return\n", .{});
                if (ret) |expr|
                    try expr.dumpIndented(writer, indent + 2);
            },
            .Break, .Continue => |nd| try putInd(
                writer,
                indent,
                "{s} {s}\n",
                .{ @tagName(self), if (nd) |label| label else "" },
            ),
            .Throw => |nd| try putInd(
                writer,
                indent,
                "{s} {s}\n",
                .{ @tagName(self), nd },
            ),
            .BinaryOp => |binaryOp| try binaryOp.dump(writer, indent),
            .Ternary => |ternary| try ternary.dump(writer, indent),
            .Function => |func| try func.dump(writer, indent),
            .If => |stmt| try stmt.dump(writer, indent),
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
