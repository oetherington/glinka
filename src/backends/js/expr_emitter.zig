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
const Allocator = std.mem.Allocator;
const expectEqualStrings = std.testing.expectEqualStrings;
const TokenType = @import("../../common/token.zig").Token.Type;
const node = @import("../../common/node.zig");
const Node = node.Node;
const Cursor = @import("../../common/cursor.zig").Cursor;
const Backend = @import("../../common/backend.zig").Backend;
const JsBackend = @import("js_backend.zig").JsBackend;
const EmitTestCase = @import("emit_test_case.zig").EmitTestCase;

fn opToString(op: TokenType) error{InvalidOp}![]const u8 {
    return switch (op) {
        .OptionChain => ".?",
        .Ellipsis => "...",
        .Add => "+",
        .AddAssign => "+=",
        .Inc => "++",
        .Sub => "-",
        .SubAssign => "-=",
        .Dec => "--",
        .Mul => "*",
        .MulAssign => "*=",
        .Pow => "**",
        .PowAssign => "**=",
        .Div => "/",
        .DivAssign => "/=",
        .Mod => "%",
        .ModAssign => "%=",
        .Assign => "=",
        .CmpEq => "==",
        .CmpStrictEq => "===",
        .LogicalNot => "!",
        .CmpNotEq => "!=",
        .CmpStrictNotEq => "!==",
        .CmpGreater => ">",
        .CmpGreaterEq => ">=",
        .CmpLess => "<",
        .CmpLessEq => "<=",
        .Nullish => "??",
        .NullishAssign => "??=",
        .BitAnd => "&",
        .BitAndAssign => "&=",
        .LogicalAnd => "&&",
        .LogicalAndAssign => "&&=",
        .BitOr => "|",
        .BitOrAssign => "|=",
        .LogicalOr => "||",
        .LogicalOrAssign => "||=",
        .BitNot => "~",
        .BitNotAssign => "~=",
        .BitXor => "^",
        .BitXorAssign => "^=",
        .ShiftRight => ">>",
        .ShiftRightAssign => ">>=",
        .ShiftRightUnsigned => ">>>",
        .ShiftRightUnsignedAssign => ">>>=",
        .ShiftLeft => "<<",
        .ShiftLeftAssign => "<<=",
        else => error.InvalidOp,
    };
}

pub fn emitExpr(self: JsBackend, value: Node) Backend.Error!void {
    try switch (value.data) {
        .Ident => |i| self.out.print("{s}", .{i}),
        .Int => |i| self.out.print("{s}", .{i}),
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
            fn cleanup(alloc: *Allocator, nd: Node) void {
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
            fn cleanup(alloc: *Allocator, nd: Node) void {
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
            fn cleanup(alloc: *Allocator, nd: Node) void {
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
            fn cleanup(alloc: *Allocator, nd: Node) void {
                alloc.destroy(nd.data.Ternary.cond);
                alloc.destroy(nd.data.Ternary.ifTrue);
                alloc.destroy(nd.data.Ternary.ifFalse);
            }
        }).cleanup,
    }).run();
}
