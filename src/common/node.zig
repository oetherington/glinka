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
const WriteContext = @import("writer.zig").WriteContext;
const Type = @import("types/type.zig").Type;
const allocate = @import("allocate.zig");

fn putInd(
    writer: anytype,
    indent: usize,
    comptime fmt: []const u8,
    args: anytype,
) !void {
    var i: usize = 0;
    while (i < indent) : (i += 1) {
        try writer.print(" ", .{});
    }

    try writer.print(fmt, args);
}

test "can format strings with indentation" {
    const ctx = try WriteContext(.{}).new(std.testing.allocator);
    defer ctx.deinit();
    try putInd(ctx.writer(), 0, "hello {s}\n", .{"world"});
    try putInd(ctx.writer(), 4, "hello {s}\n", .{"world"});
    const str = try ctx.toString();
    defer ctx.freeString(str);
    try expectEqualStrings("hello world\n    hello world\n", str);
}

fn DumpTestCase(comptime T: type, comptime nodeType: NodeType) type {
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

            try expectEqualStrings(self.expected, str);
        }
    };
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
    ) !void {
        try putInd(writer, indent, "Property\n", .{});
        try self.key.dumpIndented(writer, indent + 2);
        try self.value.dumpIndented(writer, indent + 2);
    }

    pub fn eql(self: ObjectProperty, other: ObjectProperty) bool {
        return genericEql.eql(self, other);
    }
};

test "can dump an Object" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .String, "a"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .String, "1"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(Object, .Object){
        .value = Object{ .items = &[_]ObjectProperty{
            ObjectProperty.new(nodes[0], nodes[1]),
        } },
        .expected = 
        \\Object
        \\  Property
        \\    String Node (1:1)
        \\      String: "a"
        \\    String Node (2:1)
        \\      String: "1"
        \\
        ,
    }).run();
}

test "can compare object properties for equality" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .String, "a"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .String, "1"),
        makeNode(std.testing.allocator, Cursor.new(3, 1), .String, "b"),
        makeNode(std.testing.allocator, Cursor.new(4, 1), .String, "2"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    const a = ObjectProperty.new(nodes[0], nodes[1]);
    const b = ObjectProperty.new(nodes[0], nodes[1]);
    const c = ObjectProperty.new(nodes[2], nodes[3]);

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
                else => error.InvalidScoping,
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
    ) !void {
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

test "can create Decl.Scoping from Token.Type" {
    try expectEqual(Decl.Scoping.Var, try Decl.Scoping.fromTokenType(.Var));
    try expectEqual(Decl.Scoping.Let, try Decl.Scoping.fromTokenType(.Let));
    try expectEqual(Decl.Scoping.Const, try Decl.Scoping.fromTokenType(.Const));
    try expectError(error.InvalidScoping, Decl.Scoping.fromTokenType(.Dot));
}

test "can convert Decl.Scoping to string" {
    try expectEqualStrings("var", Decl.Scoping.Var.toString());
    try expectEqualStrings("let", Decl.Scoping.Let.toString());
    try expectEqualStrings("const", Decl.Scoping.Const.toString());
}

test "can dump a Decl" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .TypeName, "number"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "1"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(Decl, .Decl){
        .value = Decl.new(.Const, "aDeclaration", nodes[0], nodes[1]),
        .expected = 
        \\Const Decl "aDeclaration"
        \\  TypeName Node (1:1)
        \\    TypeName: "number"
        \\  Int Node (2:1)
        \\    Int: "1"
        \\
        ,
    }).run();
}

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
    ) !void {
        try putInd(writer, indent, "{s} Unary Op\n", .{@tagName(self.op)});
        try self.expr.dumpIndented(writer, indent + 2);
    }
};

test "can dump a prefix UnaryOp" {
    const node = makeNode(std.testing.allocator, Cursor.new(1, 5), .Int, "1");
    defer std.testing.allocator.destroy(node);

    try (DumpTestCase(UnaryOp, .PrefixOp){
        .value = UnaryOp.new(.Sub, node),
        .expected = 
        \\PrefixOp
        \\  Sub Unary Op
        \\    Int Node (1:5)
        \\      Int: "1"
        \\
        ,
    }).run();
}

test "can dump a postfix UnaryOp" {
    const node = makeNode(std.testing.allocator, Cursor.new(1, 5), .Int, "1");
    defer std.testing.allocator.destroy(node);

    try (DumpTestCase(UnaryOp, .PostfixOp){
        .value = UnaryOp.new(.Sub, node),
        .expected = 
        \\PostfixOp
        \\  Sub Unary Op
        \\    Int Node (1:5)
        \\      Int: "1"
        \\
        ,
    }).run();
}

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
    ) !void {
        try putInd(writer, indent, "{s} Binary Op\n", .{@tagName(self.op)});
        try self.left.dumpIndented(writer, indent + 2);
        try self.right.dumpIndented(writer, indent + 2);
    }
};

test "can dump a BinaryOp" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "2"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(BinaryOp, .BinaryOp){
        .value = BinaryOp.new(.Add, nodes[0], nodes[1]),
        .expected = 
        \\Add Binary Op
        \\  Int Node (1:1)
        \\    Int: "1"
        \\  Int Node (2:1)
        \\    Int: "2"
        \\
        ,
    }).run();
}

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
    ) !void {
        try putInd(writer, indent, "Ternary Expression\n", .{});
        try self.cond.dumpIndented(writer, indent + 2);
        try self.ifTrue.dumpIndented(writer, indent + 2);
        try self.ifFalse.dumpIndented(writer, indent + 2);
    }
};

test "can dump a Ternary" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "2"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "3"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(Ternary, .Ternary){
        .value = Ternary.new(nodes[0], nodes[1], nodes[2]),
        .expected = 
        \\Ternary Expression
        \\  Int Node (1:1)
        \\    Int: "1"
        \\  Int Node (1:1)
        \\    Int: "2"
        \\  Int Node (2:1)
        \\    Int: "3"
        \\
        ,
    }).run();
}

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

    pub fn new(branches: BranchList, elseBranch: ?Node) If {
        return If{
            .branches = branches,
            .elseBranch = elseBranch,
        };
    }

    pub fn dump(
        self: If,
        writer: anytype,
        indent: usize,
    ) !void {
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

test "can check If.Branch equality" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "2"),
        makeNode(std.testing.allocator, Cursor.new(3, 1), .Int, "3"),
        makeNode(std.testing.allocator, Cursor.new(4, 1), .Int, "4"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    const a = If.Branch{ .cond = nodes[0], .ifTrue = nodes[1] };
    const b = If.Branch{ .cond = nodes[0], .ifTrue = nodes[1] };
    const c = If.Branch{ .cond = nodes[2], .ifTrue = nodes[3] };

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

test "can dump an If" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "2"),
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "3"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    var branches = If.BranchList{};
    defer branches.deinit(std.testing.allocator);

    try branches.append(std.testing.allocator, If.Branch{
        .cond = nodes[0],
        .ifTrue = nodes[1],
    });

    try (DumpTestCase(If, .If){
        .value = If.new(branches, nodes[2]),
        .expected = 
        \\If:
        \\  Cond:
        \\    Int Node (1:1)
        \\      Int: "1"
        \\  Branch:
        \\    Int Node (1:1)
        \\      Int: "2"
        \\  Else:
        \\    Int Node (1:1)
        \\      Int: "3"
        \\
        ,
    }).run();
}

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

pub const While = struct {
    cond: Node,
    body: Node,

    pub fn new(cond: Node, body: Node) While {
        return While{
            .cond = cond,
            .body = body,
        };
    }

    pub fn dump(
        self: While,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "While:\n", .{});
        try putInd(writer, indent + 2, "Condition:\n", .{});
        try self.cond.dumpIndented(writer, indent + 4);
        try putInd(writer, indent + 2, "Body:\n", .{});
        try self.body.dumpIndented(writer, indent + 4);
    }
};

test "can dump a While" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "2"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(While, .While){
        .value = While.new(nodes[0], nodes[1]),
        .expected = 
        \\While:
        \\  Condition:
        \\    Int Node (1:1)
        \\      Int: "1"
        \\  Body:
        \\    Int Node (2:1)
        \\      Int: "2"
        \\
        ,
    }).run();
}

pub const Do = struct {
    body: Node,
    cond: Node,

    pub fn new(body: Node, cond: Node) Do {
        return Do{
            .body = body,
            .cond = cond,
        };
    }

    pub fn dump(
        self: Do,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "Do:\n", .{});
        try putInd(writer, indent + 2, "Body:\n", .{});
        try self.body.dumpIndented(writer, indent + 4);
        try putInd(writer, indent + 2, "Condition:\n", .{});
        try self.cond.dumpIndented(writer, indent + 4);
    }
};

test "can dump a Do" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "2"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(Do, .Do){
        .value = Do.new(nodes[0], nodes[1]),
        .expected = 
        \\Do:
        \\  Body:
        \\    Int Node (1:1)
        \\      Int: "1"
        \\  Condition:
        \\    Int Node (2:1)
        \\      Int: "2"
        \\
        ,
    }).run();
}

pub const Labelled = struct {
    label: []const u8,
    stmt: Node,

    pub fn new(label: []const u8, stmt: Node) Labelled {
        return Labelled{
            .label = label,
            .stmt = stmt,
        };
    }

    pub fn dump(
        self: Labelled,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "Labelled \"{s}\":\n", .{self.label});
        try self.stmt.dumpIndented(writer, indent + 2);
    }
};

test "can dump a Labelled" {
    const node = makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1");
    defer std.testing.allocator.destroy(node);

    try (DumpTestCase(Labelled, .Labelled){
        .value = Labelled.new("aLabel", node),
        .expected = 
        \\Labelled "aLabel":
        \\  Int Node (1:1)
        \\    Int: "1"
        \\
        ,
    }).run();
}

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

    pub fn new(
        tryBlock: Node,
        catchBlocks: CatchList,
        finallyBlock: ?Node,
    ) Try {
        return Try{
            .tryBlock = tryBlock,
            .catchBlocks = catchBlocks,
            .finallyBlock = finallyBlock,
        };
    }

    pub fn dump(
        self: Try,
        writer: anytype,
        indent: usize,
    ) !void {
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

test "can compare Try.Catch equality" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "2"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    const a = Try.Catch{ .name = "a", .block = nodes[0] };
    const b = Try.Catch{ .name = "a", .block = nodes[0] };
    const c = Try.Catch{ .name = "b", .block = nodes[1] };

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

test "can dump a Try" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "2"),
        makeNode(std.testing.allocator, Cursor.new(3, 1), .Int, "3"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(Try, .Try){
        .value = Try.new(nodes[0], Try.CatchList{
            .items = &[_]Try.Catch{Try.Catch{
                .name = "anException",
                .block = nodes[1],
            }},
        }, nodes[2]),
        .expected = 
        \\Try:
        \\  Int Node (1:1)
        \\    Int: "1"
        \\Catch "anException":
        \\  Int Node (2:1)
        \\    Int: "2"
        \\Finally:
        \\  Int Node (3:1)
        \\    Int: "3"
        \\
        ,
    }).run();
}

pub const Switch = struct {
    pub const Case = struct {
        value: Node,
        stmts: NodeList,

        pub fn eql(a: Case, b: Case) bool {
            return genericEql.eql(a, b);
        }
    };

    pub const CaseList = std.ArrayListUnmanaged(Case);

    expr: Node,
    cases: CaseList,
    default: ?NodeList,

    pub fn new(expr: Node, cases: CaseList, default: ?NodeList) Switch {
        return Switch{
            .expr = expr,
            .cases = cases,
            .default = default,
        };
    }

    pub fn dump(
        self: Switch,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "Switch:\n", .{});
        try self.expr.dumpIndented(writer, indent + 2);

        for (self.cases.items) |item| {
            try putInd(writer, indent + 2, "Case:\n", .{});
            try item.value.dumpIndented(writer, indent + 4);
            for (item.stmts.items) |stmt|
                try stmt.dumpIndented(writer, indent + 4);
        }

        if (self.default) |default| {
            try putInd(writer, indent + 2, "Default:\n", .{});
            for (default.items) |stmt|
                try stmt.dumpIndented(writer, indent + 4);
        }
    }
};

test "can compare Switch.Case equality" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "2"),
        makeNode(std.testing.allocator, Cursor.new(3, 1), .Int, "3"),
        makeNode(std.testing.allocator, Cursor.new(4, 1), .Int, "4"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    const a = Switch.Case{
        .value = nodes[0],
        .stmts = NodeList{ .items = &[_]Node{nodes[1]} },
    };
    const b = Switch.Case{
        .value = nodes[0],
        .stmts = NodeList{ .items = &[_]Node{nodes[1]} },
    };
    const c = Switch.Case{
        .value = nodes[2],
        .stmts = NodeList{ .items = &[_]Node{nodes[3]} },
    };

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

test "can dump a Switch" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "2"),
        makeNode(std.testing.allocator, Cursor.new(3, 1), .Int, "3"),
        makeNode(std.testing.allocator, Cursor.new(4, 1), .Int, "4"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(Switch, .Switch){
        .value = Switch.new(
            nodes[0],
            Switch.CaseList{
                .items = &[_]Switch.Case{Switch.Case{
                    .value = nodes[1],
                    .stmts = NodeList{ .items = &[_]Node{nodes[2]} },
                }},
            },
            NodeList{ .items = &[_]Node{nodes[3]} },
        ),
        .expected = 
        \\Switch:
        \\  Int Node (1:1)
        \\    Int: "1"
        \\  Case:
        \\    Int Node (2:1)
        \\      Int: "2"
        \\    Int Node (3:1)
        \\      Int: "3"
        \\  Default:
        \\    Int Node (4:1)
        \\      Int: "4"
        \\
        ,
    }).run();
}

pub const Dot = struct {
    expr: Node,
    ident: []const u8,

    pub fn new(expr: Node, ident: []const u8) Dot {
        return Dot{
            .expr = expr,
            .ident = ident,
        };
    }

    pub fn dump(
        self: Dot,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "Dot \"{s}\":\n", .{self.ident});
        try self.expr.dumpIndented(writer, indent + 2);
    }
};

test "can dump a Dot" {
    const node = makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1");
    defer std.testing.allocator.destroy(node);

    try (DumpTestCase(Dot, .Dot){
        .value = Dot.new(node, "aProperty"),
        .expected = 
        \\Dot "aProperty":
        \\  Int Node (1:1)
        \\    Int: "1"
        \\
        ,
    }).run();
}

pub const ArrayAccess = struct {
    expr: Node,
    index: Node,

    pub fn new(expr: Node, index: Node) ArrayAccess {
        return ArrayAccess{
            .expr = expr,
            .index = index,
        };
    }

    pub fn dump(
        self: ArrayAccess,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "Array Access:\n", .{});
        try self.expr.dumpIndented(writer, indent + 2);
        try self.index.dumpIndented(writer, indent + 2);
    }
};

test "can dump an ArrayAccess" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "2"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(ArrayAccess, .ArrayAccess){
        .value = ArrayAccess.new(nodes[0], nodes[1]),
        .expected = 
        \\Array Access:
        \\  Int Node (1:1)
        \\    Int: "1"
        \\  Int Node (2:1)
        \\    Int: "2"
        \\
        ,
    }).run();
}

pub const Call = struct {
    expr: Node,
    args: NodeList,

    pub fn new(expr: Node, args: NodeList) Call {
        return Call{
            .expr = expr,
            .args = args,
        };
    }

    pub fn dump(
        self: Call,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "Call:\n", .{});
        try putInd(writer, indent + 2, "Function:\n", .{});
        try self.expr.dumpIndented(writer, indent + 4);
        try putInd(writer, indent + 2, "Args:\n", .{});
        for (self.args.items) |arg|
            try arg.dumpIndented(writer, indent + 4);
    }
};

test "can dump a Call" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .Int, "1"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "2"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(Call, .Call){
        .value = Call.new(nodes[0], NodeList{ .items = &[_]Node{nodes[1]} }),
        .expected = 
        \\Call:
        \\  Function:
        \\    Int Node (1:1)
        \\      Int: "1"
        \\  Args:
        \\    Int Node (2:1)
        \\      Int: "2"
        \\
        ,
    }).run();
}

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
    UnionType,
    ArrayType,
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
            .Int, .TypeName, .Ident, .String, .Template => |s| try putInd(
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
