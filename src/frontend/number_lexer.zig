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
const assert = std.debug.assert;
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("../common/token.zig").Token;
const Cursor = @import("../common/cursor.zig").Cursor;

// GRAMMAR:
//  [0-9][0-9]*         Decimal int literal
//  0[0-7]*             Octal int literal
//  0[bB][0-1]*         Binary int literal
//  0[oO][0-7]*         Octal int literal
//  0[xX][0-9a-fA-F]*   Hex int literal
//
//  Append 'n' for BigInt literal
//  Append /\.[0-9]*/ to a decimal literal for a float literal
//  Append /[eE][-+]?[0-9]*/ for exponentiation
//  Underscores can be used as separators, but:
//   - not more than one consecutive underscore
//   - not allowed as the last character in a literal
//   - not allowed after a leading 0

fn isBinary(c: u8) bool {
    return c == '0' or c == '1';
}

fn isOctal(c: u8) bool {
    return c >= '0' and c <= '7';
}

fn isDecimal(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isHex(c: u8) bool {
    return (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
}

fn lexDigits(
    lexer: *Lexer,
    start: usize,
    csr: Cursor,
    comptime validator: fn (c: u8) bool,
) void {
    lexer.index += 1;

    while (lexer.index < lexer.code.len) {
        const c = lexer.code[lexer.index];
        if (validator(c) or c == '_')
            lexer.index += 1
        else
            break;
    }

    lexer.token = Token.newData(
        Token.Type.Int,
        csr,
        lexer.code[start..lexer.index],
    );
}

fn eatDecimals(lexer: *Lexer) void {
    while (lexer.index < lexer.code.len) {
        const c = lexer.code[lexer.index];
        if (isDecimal(c) or c == '_') {
            lexer.token.data.len += 1;
            lexer.index += 1;
        } else {
            break;
        }
    }
}

fn lexExponent(lexer: *Lexer) void {
    assert(lexer.code[lexer.index] == 'e' or lexer.code[lexer.index] == 'E');

    lexer.index += 1;
    lexer.token.data.len += 1;

    if (lexer.code[lexer.index] == '-' or lexer.code[lexer.index] == '+') {
        lexer.index += 1;
        lexer.token.data.len += 1;
    }

    eatDecimals(lexer);
}

pub fn lexNumber(lexer: *Lexer) Token {
    assert(isDecimal(lexer.code[lexer.index]));

    const start = lexer.index;
    const csr = lexer.csr;

    if (lexer.code[lexer.index] == '0') {
        lexer.index += 1;
        if (lexer.index >= lexer.code.len) {
            lexer.token = Token.newData(
                .Int,
                csr,
                lexer.code[lexer.index - 1 .. lexer.index],
            );
        } else {
            switch (lexer.code[lexer.index]) {
                'b', 'B' => lexDigits(lexer, start, csr, isBinary),
                'o', 'O' => lexDigits(lexer, start, csr, isOctal),
                'x', 'X' => lexDigits(lexer, start, csr, isHex),
                '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' => {
                    lexDigits(lexer, start, csr, isDecimal);
                },
                else => lexer.token = Token.newData(
                    .Int,
                    csr,
                    lexer.code[lexer.index - 1 .. lexer.index],
                ),
            }
        }
    } else {
        lexDigits(lexer, start, csr, isDecimal);
    }

    if (lexer.token.ty == .Int and lexer.index < lexer.code.len) {
        switch (lexer.code[lexer.index]) {
            '.' => {
                lexer.token.ty = .Float;
                lexer.token.data.len += 1;
                lexer.index += 1;
                eatDecimals(lexer);
                if (lexer.code[lexer.index] == 'e' or lexer.code[lexer.index] == 'E')
                    lexExponent(lexer);
            },
            'e', 'E' => {
                lexer.token.ty = .Float;
                lexExponent(lexer);
            },
            'n' => {
                lexer.token.ty = .BigInt;
                lexer.token.data.len += 1;
                lexer.index += 1;
            },
            else => {},
        }
    }

    lexer.csr.ch += @intCast(u32, lexer.index - start);

    return lexer.token;
}

const TestCase = struct {
    code: []const u8,
    expectedType: Token.Type,

    pub fn run(self: @This()) !void {
        var lexer = Lexer.new(self.code);
        const token = lexer.next();

        const expected = self.code[1 .. self.code.len - 1];

        try std.testing.expectEqual(self.expectedType, token.ty);
        try std.testing.expectEqualStrings(expected, token.data);
        try std.testing.expectEqual(@intCast(u32, 1), token.csr.ln);
        try std.testing.expectEqual(@intCast(u32, 2), token.csr.ch);
        try std.testing.expectEqual(self.code.len - 1, lexer.index);
    }
};

test "lexNumber can lex integers" {
    const testCases = [_]TestCase{
        TestCase{ .code = " 0 ", .expectedType = .Int },
        TestCase{ .code = " 123456 ", .expectedType = .Int },
        TestCase{ .code = " 123_456 ", .expectedType = .Int },
        TestCase{ .code = " 01234 ", .expectedType = .Int },
        TestCase{ .code = " 01239 ", .expectedType = .Int },
        TestCase{ .code = " 0b10_00101 ", .expectedType = .Int },
        TestCase{ .code = " 0B1000101 ", .expectedType = .Int },
        TestCase{ .code = " 0o163646 ", .expectedType = .Int },
        TestCase{ .code = " 0O2364_26 ", .expectedType = .Int },
        TestCase{ .code = " 0x301_afBC ", .expectedType = .Int },
        TestCase{ .code = " 0X301abcD ", .expectedType = .Int },
    };

    for (testCases) |testCase|
        try testCase.run();
}

test "lexNumber can lex BigInts" {
    const testCases = [_]TestCase{
        TestCase{ .code = " 0n ", .expectedType = .BigInt },
        TestCase{ .code = " 123456n ", .expectedType = .BigInt },
        TestCase{ .code = " 123_456n ", .expectedType = .BigInt },
        TestCase{ .code = " 01234n ", .expectedType = .BigInt },
        TestCase{ .code = " 01239n ", .expectedType = .BigInt },
        TestCase{ .code = " 0b10_00101n ", .expectedType = .BigInt },
        TestCase{ .code = " 0B1000101n ", .expectedType = .BigInt },
        TestCase{ .code = " 0o163646n ", .expectedType = .BigInt },
        TestCase{ .code = " 0O2364_26n ", .expectedType = .BigInt },
        TestCase{ .code = " 0x301_afBCn ", .expectedType = .BigInt },
        TestCase{ .code = " 0X301abcDn ", .expectedType = .BigInt },
    };

    for (testCases) |testCase|
        try testCase.run();
}

test "lexNumber can lex floats" {
    const testCases = [_]TestCase{
        TestCase{ .code = " 1234.5678 ", .expectedType = .Float },
        TestCase{ .code = " 1_234.567_8 ", .expectedType = .Float },
        TestCase{ .code = " 1_234e10 ", .expectedType = .Float },
        TestCase{ .code = " 1_234e+123 ", .expectedType = .Float },
        TestCase{ .code = " 1_234e-12_3 ", .expectedType = .Float },
        TestCase{ .code = " 1_234.567_8E10 ", .expectedType = .Float },
    };

    for (testCases) |testCase|
        try testCase.run();
}
