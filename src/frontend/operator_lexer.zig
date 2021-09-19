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
const TokenType = @import("../common/token.zig").Token.Type;

const Branch = struct {
    branch: u8,
    lexer: OperatorLexer,

    pub fn new(branch: u8, lexer: OperatorLexer) Branch {
        return Branch{
            .branch = branch,
            .lexer = lexer,
        };
    }
};

const OperatorLexer = struct {
    terminal: ?TokenType,
    branches: []const Branch,

    pub const Result = struct {
        ty: TokenType,
        len: u32,

        pub fn new(ty: TokenType, len: u32) Result {
            return Result{
                .ty = ty,
                .len = len,
            };
        }
    };

    pub fn new(terminal: ?TokenType, branches: []const Branch) OperatorLexer {
        return OperatorLexer{
            .terminal = terminal,
            .branches = branches,
        };
    }

    pub fn lex(self: OperatorLexer, code: []const u8, depth: u32) ?Result {
        if (code.len < 1)
            return null;

        for (self.branches) |branch|
            if (branch.branch == code[0])
                return branch.lexer.lex(
                    code[1..],
                    depth + 1,
                ) orelse if (branch.lexer.terminal) |terminal|
                    Result.new(terminal, depth + 1)
                else
                    null;

        return if (self.terminal) |terminal|
            Result.new(terminal, depth)
        else
            null;
    }
};

const operatorLexer = OperatorLexer.new(
    null,
    &[_]Branch{
        Branch.new('.', OperatorLexer.new(
            TokenType.Dot,
            &[_]Branch{
                Branch.new('?', OperatorLexer.new(
                    TokenType.OptionChain,
                    &[_]Branch{},
                )),
                Branch.new('.', OperatorLexer.new(
                    null,
                    &[_]Branch{
                        Branch.new('.', OperatorLexer.new(
                            TokenType.Ellipsis,
                            &[_]Branch{},
                        )),
                    },
                )),
            },
        )),
        Branch.new('=', OperatorLexer.new(
            TokenType.Assign,
            &[_]Branch{
                Branch.new('=', OperatorLexer.new(
                    TokenType.CmpEq,
                    &[_]Branch{
                        Branch.new('=', OperatorLexer.new(
                            TokenType.CmpStrictEq,
                            &[_]Branch{},
                        )),
                    },
                )),
                Branch.new('>', OperatorLexer.new(
                    TokenType.Arrow,
                    &[_]Branch{},
                )),
            },
        )),
        Branch.new('+', OperatorLexer.new(
            TokenType.Add,
            &[_]Branch{
                Branch.new('=', OperatorLexer.new(
                    TokenType.AddAssign,
                    &[_]Branch{},
                )),
                Branch.new('+', OperatorLexer.new(
                    TokenType.Inc,
                    &[_]Branch{},
                )),
            },
        )),
        Branch.new('-', OperatorLexer.new(
            TokenType.Sub,
            &[_]Branch{
                Branch.new('=', OperatorLexer.new(
                    TokenType.SubAssign,
                    &[_]Branch{},
                )),
                Branch.new('-', OperatorLexer.new(
                    TokenType.Dec,
                    &[_]Branch{},
                )),
            },
        )),
        Branch.new('*', OperatorLexer.new(
            TokenType.Mul,
            &[_]Branch{
                Branch.new('=', OperatorLexer.new(
                    TokenType.MulAssign,
                    &[_]Branch{},
                )),
                Branch.new('*', OperatorLexer.new(
                    TokenType.Pow,
                    &[_]Branch{
                        Branch.new('=', OperatorLexer.new(
                            TokenType.PowAssign,
                            &[_]Branch{},
                        )),
                    },
                )),
            },
        )),
        Branch.new('/', OperatorLexer.new(
            TokenType.Div,
            &[_]Branch{
                Branch.new('=', OperatorLexer.new(
                    TokenType.DivAssign,
                    &[_]Branch{},
                )),
            },
        )),
        Branch.new('%', OperatorLexer.new(
            TokenType.Mod,
            &[_]Branch{
                Branch.new('=', OperatorLexer.new(
                    TokenType.ModAssign,
                    &[_]Branch{},
                )),
            },
        )),
        Branch.new('!', OperatorLexer.new(
            TokenType.LogicalNot,
            &[_]Branch{
                Branch.new('=', OperatorLexer.new(
                    TokenType.CmpNotEq,
                    &[_]Branch{
                        Branch.new('=', OperatorLexer.new(
                            TokenType.CmpStrictNotEq,
                            &[_]Branch{},
                        )),
                    },
                )),
            },
        )),
        Branch.new('>', OperatorLexer.new(
            TokenType.CmpGreater,
            &[_]Branch{
                Branch.new('=', OperatorLexer.new(
                    TokenType.CmpGreaterEq,
                    &[_]Branch{},
                )),
                Branch.new('>', OperatorLexer.new(
                    TokenType.ShiftRight,
                    &[_]Branch{
                        Branch.new('=', OperatorLexer.new(
                            TokenType.ShiftRightAssign,
                            &[_]Branch{},
                        )),
                        Branch.new('>', OperatorLexer.new(
                            TokenType.ShiftRightUnsigned,
                            &[_]Branch{
                                Branch.new('=', OperatorLexer.new(
                                    TokenType.ShiftRightUnsignedAssign,
                                    &[_]Branch{},
                                )),
                            },
                        )),
                    },
                )),
            },
        )),
        Branch.new('<', OperatorLexer.new(
            TokenType.CmpLess,
            &[_]Branch{
                Branch.new('=', OperatorLexer.new(
                    TokenType.CmpLessEq,
                    &[_]Branch{},
                )),
                Branch.new('<', OperatorLexer.new(
                    TokenType.ShiftLeft,
                    &[_]Branch{
                        Branch.new('=', OperatorLexer.new(
                            TokenType.ShiftLeftAssign,
                            &[_]Branch{},
                        )),
                    },
                )),
            },
        )),
        Branch.new('&', OperatorLexer.new(
            TokenType.BitAnd,
            &[_]Branch{
                Branch.new('=', OperatorLexer.new(
                    TokenType.BitAndAssign,
                    &[_]Branch{},
                )),
                Branch.new('&', OperatorLexer.new(
                    TokenType.LogicalAnd,
                    &[_]Branch{
                        Branch.new('=', OperatorLexer.new(
                            TokenType.LogicalAndAssign,
                            &[_]Branch{},
                        )),
                    },
                )),
            },
        )),
        Branch.new('|', OperatorLexer.new(
            TokenType.BitOr,
            &[_]Branch{
                Branch.new('=', OperatorLexer.new(
                    TokenType.BitOrAssign,
                    &[_]Branch{},
                )),
                Branch.new('|', OperatorLexer.new(
                    TokenType.LogicalOr,
                    &[_]Branch{
                        Branch.new('=', OperatorLexer.new(
                            TokenType.LogicalOrAssign,
                            &[_]Branch{},
                        )),
                    },
                )),
            },
        )),
        Branch.new('~', OperatorLexer.new(
            TokenType.BitNot,
            &[_]Branch{
                Branch.new('=', OperatorLexer.new(
                    TokenType.BitNotAssign,
                    &[_]Branch{},
                )),
            },
        )),
        Branch.new('^', OperatorLexer.new(
            TokenType.BitXor,
            &[_]Branch{
                Branch.new('=', OperatorLexer.new(
                    TokenType.BitXorAssign,
                    &[_]Branch{},
                )),
            },
        )),
        Branch.new('?', OperatorLexer.new(
            TokenType.Question,
            &[_]Branch{
                Branch.new('?', OperatorLexer.new(
                    TokenType.Nullish,
                    &[_]Branch{
                        Branch.new('=', OperatorLexer.new(
                            TokenType.NullishAssign,
                            &[_]Branch{},
                        )),
                    },
                )),
            },
        )),
    },
);

pub fn lexOperator(code: []const u8) ?OperatorLexer.Result {
    return operatorLexer.lex(code, 0);
}

test "OperatorLexer returns null at EOF" {
    const ty = lexOperator("");
    try expect(ty == null);
}

test "OperatorLexer can lex operators" {
    const TestCase = struct {
        const This = @This();

        str: []const u8,
        ty: TokenType,

        pub fn new(str: []const u8, ty: TokenType) This {
            return This{
                .str = str,
                .ty = ty,
            };
        }
    };

    for ([_]TestCase{
        TestCase.new(".", .Dot),
        TestCase.new(".?", .OptionChain),
        TestCase.new("...", .Ellipsis),
        TestCase.new("=>", .Arrow),
        TestCase.new("+", .Add),
        TestCase.new("+=", .AddAssign),
        TestCase.new("++", .Inc),
        TestCase.new("-", .Sub),
        TestCase.new("-=", .SubAssign),
        TestCase.new("--", .Dec),
        TestCase.new("*", .Mul),
        TestCase.new("*=", .MulAssign),
        TestCase.new("**", .Pow),
        TestCase.new("**=", .PowAssign),
        TestCase.new("/", .Div),
        TestCase.new("/=", .DivAssign),
        TestCase.new("%", .Mod),
        TestCase.new("%=", .ModAssign),
        TestCase.new("=", .Assign),
        TestCase.new("==", .CmpEq),
        TestCase.new("===", .CmpStrictEq),
        TestCase.new("!", .LogicalNot),
        TestCase.new("!=", .CmpNotEq),
        TestCase.new("!==", .CmpStrictNotEq),
        TestCase.new(">", .CmpGreater),
        TestCase.new(">=", .CmpGreaterEq),
        TestCase.new("<", .CmpLess),
        TestCase.new("<=", .CmpLessEq),
        TestCase.new("?", .Question),
        TestCase.new("??", .Nullish),
        TestCase.new("??=", .NullishAssign),
        TestCase.new("&", .BitAnd),
        TestCase.new("&=", .BitAndAssign),
        TestCase.new("&&", .LogicalAnd),
        TestCase.new("&&=", .LogicalAndAssign),
        TestCase.new("|", .BitOr),
        TestCase.new("|=", .BitOrAssign),
        TestCase.new("||", .LogicalOr),
        TestCase.new("||=", .LogicalOrAssign),
        TestCase.new("~", .BitNot),
        TestCase.new("~=", .BitNotAssign),
        TestCase.new("^", .BitXor),
        TestCase.new("^=", .BitXorAssign),
        TestCase.new(">>", .ShiftRight),
        TestCase.new(">>=", .ShiftRightAssign),
        TestCase.new(">>>", .ShiftRightUnsigned),
        TestCase.new(">>>=", .ShiftRightUnsignedAssign),
        TestCase.new("<<", .ShiftLeft),
        TestCase.new("<<=", .ShiftLeftAssign),
    }) |testCase| {
        const res = lexOperator(testCase.str).?;
        try expectEqual(testCase.ty, res.ty);
        try expectEqual(testCase.str.len, res.len);
    }
}
