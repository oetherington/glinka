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
const Cursor = @import("../common/cursor.zig").Cursor;

pub const Token = struct {
    pub const Type = enum {
        // Special tokens
        EOF,
        Invalid,

        // Literal tokens
        Ident,
        Int,
        String,
        Template,

        // Simple tokens
        LBrace,
        RBrace,
        LBrack,
        RBrack,
        LParen,
        RParen,
        Comma,
        Colon,
        Semi,

        // Operators
        Dot,
        OptionChain,
        Ellipsis,
        Arrow,
        Add,
        Sub,
        Mul,
        Div,
        Mod,
        Pow,
        Assign,
        AddAssign,
        SubAssign,
        MulAssign,
        DivAssign,
        ModAssign,
        PowAssign,
        Inc,
        Dec,
        CmpEq,
        CmpStrictEq,
        CmpNotEq,
        CmpStrictNotEq,
        CmpGreater,
        CmpLess,
        CmpGreaterEq,
        CmpLessEq,
        LogicalAnd,
        LogicalOr,
        LogicalNot,
        LogicalAndAssign,
        LogicalOrAssign,
        BitAnd,
        BitOr,
        BitNot,
        BitXor,
        BitAndAssign,
        BitOrAssign,
        BitNotAssign,
        BitXorAssign,
        ShiftLeft,
        ShiftRight,
        ShiftRightUnsigned,
        ShiftLeftAssign,
        ShiftRightAssign,
        ShiftRightUnsignedAssign,
        Question,
        Nullish,
        NullishAssign,

        // Keywords
        Var,
        Let,
        Const,
        Function,
        Void,
        Async,
        Await,
        Yield,
        Declare,
        New,
        Delete,
        This,
        Class,
        Extends,
        Implements,
        Constructor,
        Super,
        Static,
        Public,
        Private,
        Enum,
        Interface,
        Import,
        Export,
        True,
        False,
        Null,
        Undefined,
        TypeOf,
        InstanceOf,
        If,
        Else,
        Do,
        While,
        For,
        In,
        Of,
        Break,
        Continue,
        Switch,
        Case,
        Default,
        Return,
        With,
        Throw,
        Try,
        Catch,
        Finally,
    };

    ty: Type,
    csr: Cursor,
    data: []const u8,

    pub fn new(ty: Type, csr: Cursor) Token {
        return Token{
            .ty = ty,
            .csr = csr,
            .data = "",
        };
    }

    pub fn newData(ty: Type, csr: Cursor, data: []const u8) Token {
        return Token{
            .ty = ty,
            .csr = csr,
            .data = data,
        };
    }

    pub fn newInvalid() Token {
        return Token.new(Type.Invalid, Cursor.new(0, 0));
    }

    pub fn dump(self: Token) void {
        const writer = std.io.getStdOut().writer();
        writer.print("{?}\n", .{self}) catch unreachable;
    }
};

test "token can be initialized with no data" {
    const ty: Token.Type = .Int;
    const ln: u32 = 3;
    const ch: u32 = 4;
    const csr = Cursor.new(ln, ch);
    const expectedData: []const u8 = "";

    const token = Token.new(ty, csr);

    try expectEqual(ty, token.ty);
    try expectEqual(ln, token.csr.ln);
    try expectEqual(ch, token.csr.ch);
    try expectEqual(expectedData, token.data);
}

test "token can be initialized with data" {
    const ty: Token.Type = .Int;
    const ln: u32 = 3;
    const ch: u32 = 4;
    const csr = Cursor.new(ln, ch);
    const data: []const u8 = "Some sample data";

    const token = Token.newData(ty, csr, data);

    try expectEqual(ty, token.ty);
    try expectEqual(csr.ln, token.csr.ln);
    try expectEqual(csr.ch, token.csr.ch);
    try expectEqual(data, token.data);
}
