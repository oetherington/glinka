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
const Backend = @import("../backend.zig").Backend;
const JsBackend = @import("js_backend.zig").JsBackend;

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
        else => std.debug.panic(
            "Invalid Node type in emitExpr: {?}",
            .{value},
        ),
    };
}

const ExprTestCase = struct {
    inputNode: Node,
    expectedOutput: []const u8,
    cleanup: ?fn (alloc: *Allocator, nd: Node) void = null,

    pub fn run(self: ExprTestCase) !void {
        var backend = try JsBackend.new(std.testing.allocator);
        defer backend.deinit();

        try emitExpr(backend, self.inputNode);

        const str = try backend.toString();
        defer backend.freeString(str);
        try expectEqualStrings(self.expectedOutput, str);

        if (self.cleanup) |cleanup|
            cleanup(std.testing.allocator, self.inputNode);

        std.testing.allocator.destroy(self.inputNode);
    }

    pub fn makeNode(comptime ty: node.NodeType, data: anytype) !Node {
        return try node.makeNode(
            std.testing.allocator,
            Cursor.new(0, 0),
            ty,
            data,
        );
    }
};

test "JsBackend can emit ident expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(.Ident, "anIdentifier"),
        .expectedOutput = "anIdentifier",
    }).run();
}

test "JsBackend can emit int expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(.Int, "123"),
        .expectedOutput = "123",
    }).run();
}

test "JsBackend can emit string expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(.String, "'a test string'"),
        .expectedOutput = "'a test string'",
    }).run();
}

test "JsBackend can emit template expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(.Template, "`a test template`"),
        .expectedOutput = "`a test template`",
    }).run();
}

test "JsBackend can emit 'true' expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(.True, {}),
        .expectedOutput = "true",
    }).run();
}

test "JsBackend can emit 'false' expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(.False, {}),
        .expectedOutput = "false",
    }).run();
}

test "JsBackend can emit 'null' expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(.Null, {}),
        .expectedOutput = "null",
    }).run();
}

test "JsBackend can emit 'undefined' expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(.Undefined, {}),
        .expectedOutput = "undefined",
    }).run();
}

test "JsBackend can emit prefix op expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(
            .PrefixOp,
            node.UnaryOp{
                .op = .Inc,
                .expr = try ExprTestCase.makeNode(.Ident, "a"),
            },
        ),
        .expectedOutput = "(++a)",
        .cleanup = (struct {
            fn cleanup(alloc: *Allocator, nd: Node) void {
                alloc.destroy(nd.data.PrefixOp.expr);
            }
        }).cleanup,
    }).run();
}

test "JsBackend can emit postfix op expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(
            .PostfixOp,
            node.UnaryOp{
                .op = .Dec,
                .expr = try ExprTestCase.makeNode(.Ident, "a"),
            },
        ),
        .expectedOutput = "(a--)",
        .cleanup = (struct {
            fn cleanup(alloc: *Allocator, nd: Node) void {
                alloc.destroy(nd.data.PostfixOp.expr);
            }
        }).cleanup,
    }).run();
}

test "JsBackend can emit binary op expression" {
    try (ExprTestCase{
        .inputNode = try ExprTestCase.makeNode(
            .BinaryOp,
            node.BinaryOp{
                .op = .Add,
                .left = try ExprTestCase.makeNode(.Ident, "a"),
                .right = try ExprTestCase.makeNode(.Int, "4"),
            },
        ),
        .expectedOutput = "(a+4)",
        .cleanup = (struct {
            fn cleanup(alloc: *Allocator, nd: Node) void {
                alloc.destroy(nd.data.BinaryOp.left);
                alloc.destroy(nd.data.BinaryOp.right);
            }
        }).cleanup,
    }).run();
}
