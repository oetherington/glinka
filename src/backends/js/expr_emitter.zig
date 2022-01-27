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
const Allocator = std.mem.Allocator;
const node = @import("../../common/node.zig");
const Node = node.Node;
const Cursor = @import("../../common/cursor.zig").Cursor;
const Backend = @import("../../common/backend.zig").Backend;
const JsBackend = @import("js_backend.zig").JsBackend;
const EmitTestCase = @import("emit_test_case.zig").EmitTestCase;
const opToString = @import("op_to_string.zig").opToString;

pub fn emitExpr(self: JsBackend, value: Node) Backend.Error!void {
    try switch (value.data) {
        .Ident => |i| self.out.print("{s}", .{i}),
        .Int => |i| self.out.print("{s}", .{i}),
        .Float => |f| self.out.print("{s}", .{f}),
        .String => |s| self.out.print("{s}", .{s}),
        .Template => |t| self.out.print("{s}", .{t}),
        .True => self.out.print("true", .{}),
        .False => self.out.print("false", .{}),
        .Null => self.out.print("null", .{}),
        .Undefined => self.out.print("undefined", .{}),
        .PrefixOp => |op| {
            try self.out.print("({s}", .{try opToString(op.op)});
            try self.emitExpr(op.expr);
            try self.out.print(")", .{});
        },
        .PostfixOp => |op| {
            try self.out.print("(", .{});
            try self.emitExpr(op.expr);
            try self.out.print("{s})", .{try opToString(op.op)});
        },
        .BinaryOp => |op| {
            try self.out.print("(", .{});
            try self.emitExpr(op.left);
            try self.out.print("{s}", .{try opToString(op.op)});
            try self.emitExpr(op.right);
            try self.out.print(")", .{});
        },
        .Ternary => |trn| {
            try self.out.print("(", .{});
            try self.emitExpr(trn.cond);
            try self.out.print("?", .{});
            try self.emitExpr(trn.ifTrue);
            try self.out.print(":", .{});
            try self.emitExpr(trn.ifFalse);
            try self.out.print(")", .{});
        },
        .Call => |call| {
            try self.emitExpr(call.expr);
            try self.out.print("(", .{});

            var prefix: []const u8 = "";
            for (call.args.items) |arg| {
                try self.out.print("{s}", .{prefix});
                try self.emitExpr(arg);
                prefix = ", ";
            }

            try self.out.print(")", .{});
        },
        .Array => |arr| {
            try self.out.print("[ ", .{});

            for (arr.items) |item| {
                try self.emitExpr(item);
                try self.out.print(", ", .{});
            }

            try self.out.print("]", .{});
        },
        .ArrayAccess => |access| {
            try self.emitExpr(access.expr);
            try self.out.print("[", .{});
            try self.emitExpr(access.index);
            try self.out.print("]", .{});
        },
        .Dot => |dot| {
            try self.emitExpr(dot.expr);
            try self.out.print(".{s}", .{dot.ident});
        },
        .Object => |obj| {
            try self.out.print("{{ ", .{});
            for (obj.items) |prop| {
                try self.emitExpr(prop.key);
                try self.out.print(": ", .{});
                try self.emitExpr(prop.value);
                try self.out.print(", ", .{});
            }
            try self.out.print("}}", .{});
        },
        .New => |new| {
            try self.out.print("new ", .{});
            try self.emitExpr(new);
        },
        else => std.debug.panic(
            "Invalid Node type in emitExpr: {?}",
            .{value},
        ),
    };
}

test "JsBackend can emit ident expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Ident, "anIdentifier"),
        .expectedOutput = "anIdentifier;\n",
    }).run();
}

test "JsBackend can emit int expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Int, "123"),
        .expectedOutput = "123;\n",
    }).run();
}

test "JsBackend can emit float expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Int, "123.456"),
        .expectedOutput = "123.456;\n",
    }).run();
}

test "JsBackend can emit string expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.String, "'a test string'"),
        .expectedOutput = "'a test string';\n",
    }).run();
}

test "JsBackend can emit template expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Template, "`a test template`"),
        .expectedOutput = "`a test template`;\n",
    }).run();
}

test "JsBackend can emit 'true' expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.True, {}),
        .expectedOutput = "true;\n",
    }).run();
}

test "JsBackend can emit 'false' expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.False, {}),
        .expectedOutput = "false;\n",
    }).run();
}

test "JsBackend can emit 'null' expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Null, {}),
        .expectedOutput = "null;\n",
    }).run();
}

test "JsBackend can emit 'undefined' expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(.Undefined, {}),
        .expectedOutput = "undefined;\n",
    }).run();
}

test "JsBackend can emit prefix op expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(
            .PrefixOp,
            node.UnaryOp{
                .op = .Inc,
                .expr = EmitTestCase.makeNode(.Ident, "a"),
            },
        ),
        .expectedOutput = "(++a);\n",
        .cleanup = (struct {
            fn cleanup(alloc: Allocator, nd: Node) void {
                alloc.destroy(nd.data.PrefixOp.expr);
            }
        }).cleanup,
    }).run();
}

test "JsBackend can emit postfix op expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(
            .PostfixOp,
            node.UnaryOp{
                .op = .Dec,
                .expr = EmitTestCase.makeNode(.Ident, "a"),
            },
        ),
        .expectedOutput = "(a--);\n",
        .cleanup = (struct {
            fn cleanup(alloc: Allocator, nd: Node) void {
                alloc.destroy(nd.data.PostfixOp.expr);
            }
        }).cleanup,
    }).run();
}

test "JsBackend can emit binary op expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(
            .BinaryOp,
            node.BinaryOp{
                .op = .Add,
                .left = EmitTestCase.makeNode(.Ident, "a"),
                .right = EmitTestCase.makeNode(.Int, "4"),
            },
        ),
        .expectedOutput = "(a+4);\n",
        .cleanup = (struct {
            fn cleanup(alloc: Allocator, nd: Node) void {
                alloc.destroy(nd.data.BinaryOp.left);
                alloc.destroy(nd.data.BinaryOp.right);
            }
        }).cleanup,
    }).run();
}

test "JsBackend can emit ternary expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(
            .Ternary,
            node.Ternary{
                .cond = EmitTestCase.makeNode(.Ident, "a"),
                .ifTrue = EmitTestCase.makeNode(.Int, "3"),
                .ifFalse = EmitTestCase.makeNode(.False, {}),
            },
        ),
        .expectedOutput = "(a?3:false);\n",
        .cleanup = (struct {
            fn cleanup(alloc: Allocator, nd: Node) void {
                alloc.destroy(nd.data.Ternary.cond);
                alloc.destroy(nd.data.Ternary.ifTrue);
                alloc.destroy(nd.data.Ternary.ifFalse);
            }
        }).cleanup,
    }).run();
}

test "JsBackend can emit function call expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(
            .Call,
            node.Call{
                .expr = EmitTestCase.makeNode(.Ident, "aFunction"),
                .args = node.NodeList{
                    .items = &[_]Node{
                        EmitTestCase.makeNode(.Int, "4"),
                        EmitTestCase.makeNode(.String, "'a'"),
                    },
                },
            },
        ),
        .expectedOutput = "aFunction(4, 'a');\n",
        .cleanup = (struct {
            fn cleanup(alloc: Allocator, nd: Node) void {
                alloc.destroy(nd.data.Call.expr);
                alloc.destroy(nd.data.Call.args.items[0]);
                alloc.destroy(nd.data.Call.args.items[1]);
            }
        }).cleanup,
    }).run();
}

test "JsBackend can emit array literal expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(
            .Array,
            node.NodeList{
                .items = &[_]Node{
                    EmitTestCase.makeNode(.Int, "1"),
                    EmitTestCase.makeNode(.String, "'a'"),
                    EmitTestCase.makeNode(.Null, {}),
                },
            },
        ),
        .expectedOutput = "[ 1, 'a', null, ];\n",
        .cleanup = (struct {
            fn cleanup(alloc: Allocator, nd: Node) void {
                alloc.destroy(nd.data.Array.items[0]);
                alloc.destroy(nd.data.Array.items[1]);
                alloc.destroy(nd.data.Array.items[2]);
            }
        }).cleanup,
    }).run();
}

test "JsBackend can emit array access expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(
            .ArrayAccess,
            node.ArrayAccess{
                .expr = EmitTestCase.makeNode(.Ident, "anArray"),
                .index = EmitTestCase.makeNode(.Int, "1"),
            },
        ),
        .expectedOutput = "anArray[1];\n",
        .cleanup = (struct {
            fn cleanup(alloc: Allocator, nd: Node) void {
                alloc.destroy(nd.data.ArrayAccess.expr);
                alloc.destroy(nd.data.ArrayAccess.index);
            }
        }).cleanup,
    }).run();
}

test "JsBackend can emit dot expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(
            .Dot,
            node.Dot{
                .expr = EmitTestCase.makeNode(.Ident, "anObject"),
                .ident = "aProperty",
            },
        ),
        .expectedOutput = "anObject.aProperty;\n",
        .cleanup = (struct {
            fn cleanup(alloc: Allocator, nd: Node) void {
                alloc.destroy(nd.data.Dot.expr);
            }
        }).cleanup,
    }).run();
}

test "JsBackend can emit object literal expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(
            .Object,
            node.Object{
                .items = &[_]node.ObjectProperty{
                    node.ObjectProperty.new(
                        EmitTestCase.makeNode(.Ident, "a"),
                        EmitTestCase.makeNode(.Int, "0"),
                    ),
                    node.ObjectProperty.new(
                        EmitTestCase.makeNode(.String, "'b'"),
                        EmitTestCase.makeNode(.Float, "0.0"),
                    ),
                },
            },
        ),
        .expectedOutput = "{ a: 0, 'b': 0.0, };\n",
        .cleanup = (struct {
            fn cleanup(alloc: Allocator, nd: Node) void {
                alloc.destroy(nd.data.Object.items[0].key);
                alloc.destroy(nd.data.Object.items[0].value);
                alloc.destroy(nd.data.Object.items[1].key);
                alloc.destroy(nd.data.Object.items[1].value);
            }
        }).cleanup,
    }).run();
}

test "JsBackend can emit new expression" {
    try (EmitTestCase{
        .inputNode = EmitTestCase.makeNode(
            .New,
            EmitTestCase.makeNode(.Ident, "MyClass"),
        ),
        .expectedOutput = "new MyClass;\n",
        .cleanup = (struct {
            fn cleanup(alloc: Allocator, nd: Node) void {
                alloc.destroy(nd.data.New);
            }
        }).cleanup,
    }).run();
}
