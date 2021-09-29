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
const assert = std.debug.assert;
const Cursor = @import("../common/cursor.zig").Cursor;
const Token = @import("../common/token.zig").Token;
const lexOperator = @import("operator_lexer.zig").lexOperator;

const keywordMap = std.ComptimeStringMap(Token.Type, .{
    .{ "var", .Var },
    .{ "let", .Let },
    .{ "const", .Const },
    .{ "function", .Function },
    .{ "void", .Void },
    .{ "async", .Async },
    .{ "await", .Await },
    .{ "yield", .Yield },
    .{ "declare", .Declare },
    .{ "new", .New },
    .{ "delete", .Delete },
    .{ "this", .This },
    .{ "class", .Class },
    .{ "extends", .Extends },
    .{ "implements", .Implements },
    .{ "constructor", .Constructor },
    .{ "super", .Super },
    .{ "static", .Static },
    .{ "public", .Public },
    .{ "private", .Private },
    .{ "enum", .Enum },
    .{ "interface", .Interface },
    .{ "import", .Import },
    .{ "export", .Export },
    .{ "true", .True },
    .{ "false", .False },
    .{ "null", .Null },
    .{ "undefined", .Undefined },
    .{ "typeof", .TypeOf },
    .{ "instanceof", .InstanceOf },
    .{ "if", .If },
    .{ "else", .Else },
    .{ "do", .Do },
    .{ "while", .While },
    .{ "for", .For },
    .{ "in", .In },
    .{ "of", .Of },
    .{ "break", .Break },
    .{ "continue", .Continue },
    .{ "switch", .Switch },
    .{ "case", .Case },
    .{ "default", .Default },
    .{ "return", .Return },
    .{ "with", .With },
    .{ "throw", .Throw },
    .{ "try", .Try },
    .{ "catch", .Catch },
    .{ "finally", .Finally },
});

fn getIdentTokenType(ident: []const u8) Token.Type {
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
    const Context = struct {
        index: u64,
        csr: Cursor,
        token: Token,
    };

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

    pub fn save(self: Lexer) Context {
        return Context{
            .index = self.index,
            .csr = self.csr,
            .token = self.token,
        };
    }

    pub fn restore(self: *Lexer, ctx: Context) void {
        self.index = ctx.index;
        self.csr = ctx.csr;
        self.token = ctx.token;
    }

    fn atom(self: *Lexer, ty: Token.Type) Token {
        self.token = Token.new(ty, self.csr);
        self.csr.ch += 1;
        self.index += 1;
        return self.token;
    }

    fn atomData(self: *Lexer, ty: Token.Type) Token {
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
            Token.Type.Int,
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

        const ty: Token.Type = if (delim == '`') .Template else .String;
        const data = self.code[start..self.index];
        self.token = Token.newData(ty, csr, data);

        return self.token;
    }

    pub fn operator(self: *Lexer) Token {
        if (lexOperator(self.code[self.index..])) |res| {
            self.token = Token.new(res.ty, self.csr);
            self.index += res.len;
            self.csr.ch += res.len;
            return self.token;
        } else {
            return self.atomData(Token.Type.Invalid);
        }
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
                '{' => return self.atom(Token.Type.LBrace),
                '}' => return self.atom(Token.Type.RBrace),
                '[' => return self.atom(Token.Type.LBrack),
                ']' => return self.atom(Token.Type.RBrack),
                '(' => return self.atom(Token.Type.LParen),
                ')' => return self.atom(Token.Type.RParen),
                ',' => return self.atom(Token.Type.Comma),
                ':' => return self.atom(Token.Type.Colon),
                ';' => return self.atom(Token.Type.Semi),
                '/' => {
                    if (self.index + 1 >= self.code.len)
                        return self.operator();

                    self.index += 1;

                    switch (self.code[self.index]) {
                        '*' => {
                            self.index += 1;

                            while (self.index < self.code.len) {
                                if (self.code[self.index] == '/' and self.code[self.index - 1] == '*') {
                                    break;
                                } else if (self.code[self.index] == '\n') {
                                    self.csr.ln += 1;
                                    self.csr.ch = 1;
                                }

                                self.index += 1;
                                self.csr.ch += 1;
                            }

                            self.index += 1;
                            continue :nextLoop;
                        },
                        '/' => {
                            self.index += 1;

                            while (self.index < self.code.len) {
                                if (self.code[self.index] == '\n')
                                    break;

                                self.index += 1;
                            }

                            self.index += 1;
                            self.csr.ln += 1;
                            self.csr.ch = 1;
                            continue :nextLoop;
                        },
                        else => {
                            self.index -= 1;
                            return self.operator();
                        },
                    }
                },
                '.',
                '=',
                '+',
                '-',
                '*',
                '%',
                '!',
                '>',
                '<',
                '&',
                '|',
                '~',
                '^',
                '?',
                => return self.operator(),
                else => return self.atomData(Token.Type.Invalid),
            }
        }

        return self.atom(Token.Type.EOF);
    }
};

test "can classify keywords" {
    try expectEqual(Token.Type.Ident, getIdentTokenType("not_a_keyword"));
    try expectEqual(Token.Type.Class, getIdentTokenType("class"));
    try expectEqual(Token.Type.True, getIdentTokenType("true"));
}

test "can classify identifier characters" {
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

test "can classify integer characters" {
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
    try expectEqual(Token.Type.Invalid, lexer.token.ty);
}

test "lexer can detect EOF" {
    const code = "";
    var lexer = Lexer.new(code[0..]);
    const tkn = lexer.next();
    try expectEqual(Token.Type.EOF, tkn.ty);

    const nullTerminated = "\x00 this is never lexed";
    lexer = Lexer.new(nullTerminated);
    const tkn2 = lexer.next();
    try expectEqual(Token.Type.EOF, tkn2.ty);
}

test "lexer can lex simple atoms" {
    const code = "{";
    var lexer = Lexer.new(code[0..]);
    const tkn = lexer.next();
    try expectEqual(Token.Type.LBrace, tkn.ty);
    try expectEqual(@intCast(u64, 1), tkn.csr.ln);
    try expectEqual(@intCast(u64, 1), tkn.csr.ch);
    try expectEqual(@intCast(u64, 1), lexer.csr.ln);
    try expectEqual(@intCast(u64, 2), lexer.csr.ch);
    try expectEqual(@intCast(u64, 1), lexer.index);
}

test "lexer can lex operators" {
    const code = "++";
    var lexer = Lexer.new(code[0..]);
    const tkn = lexer.next();
    try expectEqual(Token.Type.Inc, tkn.ty);
    try expectEqual(@intCast(u64, 1), tkn.csr.ln);
    try expectEqual(@intCast(u64, 1), tkn.csr.ch);
    try expectEqual(@intCast(u64, 1), lexer.csr.ln);
    try expectEqual(@intCast(u64, 3), lexer.csr.ch);
    try expectEqual(@intCast(u64, 2), lexer.index);

    lexer.code = "c";
    lexer.index = 0;
    const inv = lexer.operator();
    try expectEqual(Token.Type.Invalid, inv.ty);
}

test "lexer can lex divide" {
    const code = "/";
    var lexer = Lexer.new(code[0..]);
    const tkn = lexer.next();
    try expectEqual(Token.Type.Div, tkn.ty);
}

test "lexer can skip C-style comments" {
    const code = "/* A \ncomment*/.";
    var lexer = Lexer.new(code[0..]);
    const tkn = lexer.next();
    try expectEqual(Token.Type.Dot, tkn.ty);
    try expectEqual(@intCast(u64, 2), tkn.csr.ln);
    try expectEqual(@intCast(u64, 10), tkn.csr.ch);
}

test "lexer can skip C++-style comments" {
    const code = "// A comment\n.";
    var lexer = Lexer.new(code[0..]);
    const tkn = lexer.next();
    try expectEqual(Token.Type.Dot, tkn.ty);
    try expectEqual(@intCast(u64, 2), tkn.csr.ln);
    try expectEqual(@intCast(u64, 1), tkn.csr.ch);
}

test "lexer can skip whitespace" {
    const code = " \t\r\n .";
    var lexer = Lexer.new(code[0..]);
    const tkn = lexer.next();
    try expectEqual(Token.Type.Dot, tkn.ty);
    try expectEqual(@intCast(u64, 2), tkn.csr.ln);
    try expectEqual(@intCast(u64, 2), tkn.csr.ch);
}

test "lexer can lex invalid characters" {
    const code = "£";
    var lexer = Lexer.new(code[0..]);
    const tkn = lexer.next();
    const expectedCode: []const u8 = code[0..1];
    try expectEqual(Token.Type.Invalid, tkn.ty);
    try expectEqual(expectedCode, tkn.data);
}

test "lexer can lex identifiers" {
    const code = " anIdent0_ . ";
    var lexer = Lexer.new(code[0..]);

    const ident = lexer.next();
    try expectEqual(Token.Type.Ident, ident.ty);
    try expectEqualStrings("anIdent0_", ident.data);
    try expectEqual(@intCast(u32, 1), ident.csr.ln);
    try expectEqual(@intCast(u32, 2), ident.csr.ch);

    const dot = lexer.next();
    try expectEqual(Token.Type.Dot, dot.ty);
    try expectEqual(@intCast(u32, 1), dot.csr.ln);
    try expectEqual(@intCast(u32, 12), dot.csr.ch);
}

test "lexer can lex keywords" {
    const code = " null . ";
    var lexer = Lexer.new(code[0..]);

    const ident = lexer.next();
    try expectEqual(Token.Type.Null, ident.ty);
    try expectEqualStrings("null", ident.data);
    try expectEqual(@intCast(u32, 1), ident.csr.ln);
    try expectEqual(@intCast(u32, 2), ident.csr.ch);

    const dot = lexer.next();
    try expectEqual(Token.Type.Dot, dot.ty);
    try expectEqual(@intCast(u32, 1), dot.csr.ln);
    try expectEqual(@intCast(u32, 7), dot.csr.ch);
}

test "lexer can lex integers" {
    const code = " 123456 . ";
    var lexer = Lexer.new(code[0..]);

    const ident = lexer.next();
    try expectEqual(Token.Type.Int, ident.ty);
    try expectEqualStrings("123456", ident.data);
    try expectEqual(@intCast(u32, 1), ident.csr.ln);
    try expectEqual(@intCast(u32, 2), ident.csr.ch);

    const dot = lexer.next();
    try expectEqual(Token.Type.Dot, dot.ty);
    try expectEqual(@intCast(u32, 1), dot.csr.ln);
    try expectEqual(@intCast(u32, 9), dot.csr.ch);
}

test "lexer can lex strings" {
    const StringTestCase = struct {
        code: []const u8,
        expectedType: Token.Type = .String,
        dotCursor: ?Cursor = null,

        pub fn run(comptime self: @This()) anyerror!void {
            const input = " " ++ self.code ++ " . ";
            var lexer = Lexer.new(input[0..]);

            const str = lexer.next();
            try expectEqual(self.expectedType, str.ty);
            try expectEqualStrings(self.code, str.data);

            const dot = lexer.next();
            try expectEqual(Token.Type.Dot, dot.ty);
            if (self.dotCursor) |csr| {
                try expectEqual(csr, dot.csr);
            } else {
                try expectEqual(@intCast(u32, 1), dot.csr.ln);
                try expectEqual(@intCast(u32, self.code.len + 3), dot.csr.ch);
            }
        }
    };

    try (StringTestCase{ .code = "\"hello world\"" }).run();
    try (StringTestCase{ .code = "'hello world'" }).run();
    try (StringTestCase{ .code = "\"\"" }).run();
    try (StringTestCase{ .code = "\"hello\\\"world\"" }).run();
    try (StringTestCase{ .code = "\"hello\\\\\"" }).run();
    try (StringTestCase{ .code = "\"hello\\\\\\\"world\"" }).run();
    try (StringTestCase{
        .code = "`hello\nworld`",
        .expectedType = .Template,
        .dotCursor = comptime Cursor.new(2, 8),
    }).run();

    var lexer = Lexer.new("'an unterminated string");
    const str = lexer.next();
    try expectEqual(Token.Type.Invalid, str.ty);
}

test "lexer can be saved and restored" {
    const code: []const u8 = ". ; &";
    var lexer = Lexer.new(code);

    var tkn = lexer.next();
    try expectEqual(Token.Type.Dot, tkn.ty);

    const ctx = lexer.save();

    tkn = lexer.next();
    try expectEqual(Token.Type.Semi, tkn.ty);

    tkn = lexer.next();
    try expectEqual(Token.Type.BitAnd, tkn.ty);

    lexer.restore(ctx);

    tkn = lexer.next();
    try expectEqual(Token.Type.Semi, tkn.ty);
}
