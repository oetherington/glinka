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
const assert = std.debug.assert;
const Cursor = @import("../common/cursor.zig").Cursor;
const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

const keywordMap = std.ComptimeStringMap(TokenType, .{
    .{ "class", .Class },
    .{ "const", .Const },
    .{ "constructor", .Constructor },
    .{ "declare", .Declare },
    .{ "default", .Default },
    .{ "enum", .Enum },
    .{ "export", .Export },
    .{ "extends", .Extends },
    .{ "false", .False },
    .{ "function", .Function },
    .{ "implements", .Implements },
    .{ "import", .Import },
    .{ "interface", .Interface },
    .{ "let", .Let },
    .{ "new", .New },
    .{ "null", .Null },
    .{ "private", .Private },
    .{ "public", .Public },
    .{ "require", .Require },
    .{ "static", .Static },
    .{ "true", .True },
    .{ "typeof", .Typeof },
    .{ "undefined", .Undefined },
    .{ "var", .Var },
});

fn getIdentTokenType(ident: []const u8) TokenType {
    return keywordMap.get(ident) orelse .Ident;
}

fn isIdent0(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_' or c == '$';
}

fn isNum(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isIdent(c: u8) bool {
    return isIdent0(c) or isNum(c);
}

pub const Lexer = struct {
    code: []const u8,
    index: u64,
    csr: Cursor,
    token: Token,

    pub fn new(code: []const u8) Lexer {
        return Lexer{
            .code = code,
            .index = 0,
            .csr = Cursor.new(1, 1),
            .token = Token.newInvalid(),
        };
    }

    fn atom(self: *Lexer, ty: TokenType) Token {
        self.token = Token.new(ty, self.csr);
        self.csr.ch += 1;
        self.index += 1;
        return self.token;
    }

    fn atomData(self: *Lexer, ty: TokenType) Token {
        const data = self.code[self.index .. self.index + 1];
        self.token = Token.newData(ty, self.csr, data);
        self.csr.ch += 1;
        self.index += 1;
        return self.token;
    }

    fn ident(self: *Lexer) Token {
        assert(isIdent0(self.code[self.index]));

        const start = self.index;
        self.index += 1;

        while (self.index < self.code.len and isIdent(self.code[self.index])) {
            self.index += 1;
        }

        const data = self.code[start..self.index];
        self.token = Token.newData(getIdentTokenType(data), self.csr, data);
        self.csr.ch += @intCast(u32, self.index - start);

        return self.token;
    }

    // TODO Handle floats, scientific notation, etc.
    fn number(self: *Lexer) Token {
        assert(isNum(self.code[self.index]));

        const start = self.index;
        self.index += 1;

        while (self.index < self.code.len and isNum(self.code[self.index])) {
            self.index += 1;
        }

        self.token = Token.newData(
            TokenType.Int,
            self.csr,
            self.code[start..self.index],
        );

        self.csr.ch += @intCast(u32, self.index - start);

        return self.token;
    }

    fn string(self: *Lexer) Token {
        const delim = self.code[self.index];
        assert(delim == '\'' or delim == '"' or delim == '`');

        const csr = self.csr;
        const start = self.index;
        self.index += 1;
        self.csr.ch += 1;

        var slashes: usize = 0;
        while (self.index < self.code.len) {
            const ch = self.code[self.index];

            if (ch == '\\') {
                slashes += 1;
                self.index += 1;
                self.csr.ch += 1;
                continue;
            } else if (ch == '\n') {
                // TODO: New lines should only be valid inside templates
                self.csr.ln += 1;
                self.csr.ch = 1;
            } else if (ch == delim and slashes & 1 == 0) {
                break;
            } else {
                self.csr.ch += 1;
            }

            self.index += 1;
            slashes = 0;
        }

        if (self.index >= self.code.len or self.code[self.index] != delim) {
            self.token = Token.new(.Invalid, csr);
            return self.token;
        }

        self.index += 1;
        self.csr.ch += 1;

        const ty: TokenType = if (delim == '`') .Template else .String;
        const data = self.code[start..self.index];
        self.token = Token.newData(ty, csr, data);

        return self.token;
    }

    pub fn next(self: *Lexer) Token {
        nextLoop: while (self.index < self.code.len) {
            switch (self.code[self.index]) {
                0 => break :nextLoop,
                ' ', '\t', '\r' => {
                    self.index += 1;
                    self.csr.ch += 1;
                },
                '\n' => {
                    self.index += 1;
                    self.csr.ln += 1;
                    self.csr.ch = 1;
                },
                'a'...'z', 'A'...'Z', '_' => return self.ident(),
                '0'...'9' => return self.number(),
                '\'', '"', '`' => return self.string(),
                '.' => return self.atom(TokenType.Dot),
                ',' => return self.atom(TokenType.Comma),
                ':' => return self.atom(TokenType.Colon),
                ';' => return self.atom(TokenType.Semi),
                '?' => return self.atom(TokenType.Question),
                '=' => return self.atom(TokenType.Eq),
                '{' => return self.atom(TokenType.LBrace),
                '}' => return self.atom(TokenType.RBrace),
                '[' => return self.atom(TokenType.LBrack),
                ']' => return self.atom(TokenType.RBrack),
                '(' => return self.atom(TokenType.LParen),
                ')' => return self.atom(TokenType.RParen),
                else => return self.atomData(TokenType.Invalid),
            }
        }

        return self.atom(TokenType.EOF);
    }
};

test "Can classify keywords" {
    try expectEqual(TokenType.Ident, getIdentTokenType("not_a_keyword"));
    try expectEqual(TokenType.Class, getIdentTokenType("class"));
    try expectEqual(TokenType.True, getIdentTokenType("true"));
}

test "Can classify identifier characters" {
    var c: u8 = 'a';
    while (c <= 'z') : (c += 1) {
        try expect(isIdent0(c));
        try expect(isIdent(c));
    }

    c = 'A';
    while (c <= 'Z') : (c += 1) {
        try expect(isIdent0(c));
        try expect(isIdent(c));
    }

    c = '0';
    while (c <= '9') : (c += 1) {
        try expect(!isIdent0(c));
        try expect(isIdent(c));
    }

    try expect(isIdent0('_'));
    try expect(isIdent('_'));

    try expect(isIdent0('$'));
    try expect(isIdent('$'));
}

test "Can classify integer characters" {
    var c: u8 = '0';
    while (c <= '9') : (c += 1) {
        try expect(isNum(c));
    }
}

test "lexer can be initialized" {
    const code: []const u8 = "some sample code";
    const lexer = Lexer.new(code);
    try expectEqual(code, lexer.code);
    try expectEqual(@intCast(u64, 0), lexer.index);
    try expectEqual(@intCast(u64, 1), lexer.csr.ln);
    try expectEqual(@intCast(u64, 1), lexer.csr.ch);
    try expectEqual(TokenType.Invalid, lexer.token.ty);
}

test "lexer can detect EOF" {
    const code = "";
    var lexer = Lexer.new(code[0..]);
    const tkn = lexer.next();
    try expectEqual(TokenType.EOF, tkn.ty);
}

test "lexer can lex single character token" {
    const code = ".";
    var lexer = Lexer.new(code[0..]);
    const tkn = lexer.next();
    try expectEqual(TokenType.Dot, tkn.ty);
    try expectEqual(@intCast(u64, 1), tkn.csr.ln);
    try expectEqual(@intCast(u64, 1), tkn.csr.ch);
    try expectEqual(@intCast(u64, 1), lexer.csr.ln);
    try expectEqual(@intCast(u64, 2), lexer.csr.ch);
    try expectEqual(@intCast(u64, 1), lexer.index);
}

test "lexer can skip whitespace" {
    const code = " \t\r\n .";
    var lexer = Lexer.new(code[0..]);
    const tkn = lexer.next();
    try expectEqual(TokenType.Dot, tkn.ty);
    try expectEqual(@intCast(u64, 2), tkn.csr.ln);
    try expectEqual(@intCast(u64, 2), tkn.csr.ch);
}

test "lexer can lex invalid characters" {
    const code = "£";
    var lexer = Lexer.new(code[0..]);
    const tkn = lexer.next();
    const expectedCode: []const u8 = code[0..1];
    try expectEqual(TokenType.Invalid, tkn.ty);
    try expectEqual(expectedCode, tkn.data);
}

test "lexer can lex identifiers" {
    const code = " anIdent0_ . ";
    var lexer = Lexer.new(code[0..]);

    const ident = lexer.next();
    try expectEqual(TokenType.Ident, ident.ty);
    try expectEqualSlices(u8, "anIdent0_", ident.data);
    try expectEqual(@intCast(u32, 1), ident.csr.ln);
    try expectEqual(@intCast(u32, 2), ident.csr.ch);

    const dot = lexer.next();
    try expectEqual(TokenType.Dot, dot.ty);
    try expectEqual(@intCast(u32, 1), dot.csr.ln);
    try expectEqual(@intCast(u32, 12), dot.csr.ch);
}

test "lexer can lex keywords" {
    const code = " null . ";
    var lexer = Lexer.new(code[0..]);

    const ident = lexer.next();
    try expectEqual(TokenType.Null, ident.ty);
    try expectEqualSlices(u8, "null", ident.data);
    try expectEqual(@intCast(u32, 1), ident.csr.ln);
    try expectEqual(@intCast(u32, 2), ident.csr.ch);

    const dot = lexer.next();
    try expectEqual(TokenType.Dot, dot.ty);
    try expectEqual(@intCast(u32, 1), dot.csr.ln);
    try expectEqual(@intCast(u32, 7), dot.csr.ch);
}

test "lexer can lex integers" {
    const code = " 123456 . ";
    var lexer = Lexer.new(code[0..]);

    const ident = lexer.next();
    try expectEqual(TokenType.Int, ident.ty);
    try expectEqualSlices(u8, "123456", ident.data);
    try expectEqual(@intCast(u32, 1), ident.csr.ln);
    try expectEqual(@intCast(u32, 2), ident.csr.ch);

    const dot = lexer.next();
    try expectEqual(TokenType.Dot, dot.ty);
    try expectEqual(@intCast(u32, 1), dot.csr.ln);
    try expectEqual(@intCast(u32, 9), dot.csr.ch);
}

test "lexer can lex strings" {
    const StringTestCase = struct {
        code: []const u8,
        expectedType: TokenType = .String,

        pub fn run(comptime self: @This()) anyerror!void {
            const input = " " ++ self.code ++ " . ";
            var lexer = Lexer.new(input[0..]);

            const str = lexer.next();
            try expectEqual(self.expectedType, str.ty);
            try expectEqualSlices(u8, self.code, str.data);

            const dot = lexer.next();
            try expectEqual(TokenType.Dot, dot.ty);
            try expectEqual(@intCast(u32, 1), dot.csr.ln);
            try expectEqual(@intCast(u32, self.code.len + 3), dot.csr.ch);
        }
    };

    try (StringTestCase{ .code = "\"hello world\"" }).run();
    try (StringTestCase{ .code = "'hello world'" }).run();
    try (StringTestCase{ .code = "\"\"" }).run();
    try (StringTestCase{ .code = "\"hello\\\"world\"" }).run();
    try (StringTestCase{ .code = "\"hello\\\\\"" }).run();
    try (StringTestCase{ .code = "\"hello\\\\\\\"world\"" }).run();
    try (StringTestCase{
        .code = "`hello world`",
        .expectedType = .Template,
    }).run();
}
