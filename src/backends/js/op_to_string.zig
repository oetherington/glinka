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
const expectEqualStrings = std.testing.expectEqualStrings;
const expectError = std.testing.expectError;
const TokenType = @import("../../common/token.zig").Token.Type;

pub fn opToString(op: TokenType) error{InvalidOp}![]const u8 {
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
        .Delete => "delete ",
        .TypeOf => "typeof ",
        else => error.InvalidOp,
    };
}

test "JSBackend can convert operators to strings" {
    const TestCase = struct {
        pub fn run(ty: TokenType, expected: []const u8) !void {
            const str = try opToString(ty);
            try expectEqualStrings(expected, str);
        }
    };

    try TestCase.run(.OptionChain, ".?");
    try TestCase.run(.Ellipsis, "...");
    try TestCase.run(.Add, "+");
    try TestCase.run(.AddAssign, "+=");
    try TestCase.run(.Inc, "++");
    try TestCase.run(.Sub, "-");
    try TestCase.run(.SubAssign, "-=");
    try TestCase.run(.Dec, "--");
    try TestCase.run(.Mul, "*");
    try TestCase.run(.MulAssign, "*=");
    try TestCase.run(.Pow, "**");
    try TestCase.run(.PowAssign, "**=");
    try TestCase.run(.Div, "/");
    try TestCase.run(.DivAssign, "/=");
    try TestCase.run(.Mod, "%");
    try TestCase.run(.ModAssign, "%=");
    try TestCase.run(.Assign, "=");
    try TestCase.run(.CmpEq, "==");
    try TestCase.run(.CmpStrictEq, "===");
    try TestCase.run(.LogicalNot, "!");
    try TestCase.run(.CmpNotEq, "!=");
    try TestCase.run(.CmpStrictNotEq, "!==");
    try TestCase.run(.CmpGreater, ">");
    try TestCase.run(.CmpGreaterEq, ">=");
    try TestCase.run(.CmpLess, "<");
    try TestCase.run(.CmpLessEq, "<=");
    try TestCase.run(.Nullish, "??");
    try TestCase.run(.NullishAssign, "??=");
    try TestCase.run(.BitAnd, "&");
    try TestCase.run(.BitAndAssign, "&=");
    try TestCase.run(.LogicalAnd, "&&");
    try TestCase.run(.LogicalAndAssign, "&&=");
    try TestCase.run(.BitOr, "|");
    try TestCase.run(.BitOrAssign, "|=");
    try TestCase.run(.LogicalOr, "||");
    try TestCase.run(.LogicalOrAssign, "||=");
    try TestCase.run(.BitNot, "~");
    try TestCase.run(.BitNotAssign, "~=");
    try TestCase.run(.BitXor, "^");
    try TestCase.run(.BitXorAssign, "^=");
    try TestCase.run(.ShiftRight, ">>");
    try TestCase.run(.ShiftRightAssign, ">>=");
    try TestCase.run(.ShiftRightUnsigned, ">>>");
    try TestCase.run(.ShiftRightUnsignedAssign, ">>>=");
    try TestCase.run(.ShiftLeft, "<<");
    try TestCase.run(.ShiftLeftAssign, "<<=");
    try TestCase.run(.Delete, "delete ");
    try TestCase.run(.TypeOf, "typeof ");
}

test "JSBackend throws an error for invalid operators" {
    const ty = TokenType.LBrace;
    const result = opToString(ty);
    try expectError(error.InvalidOp, result);
}
