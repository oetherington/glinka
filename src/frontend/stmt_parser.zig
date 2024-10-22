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
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const TsParser = @import("ts_parser.zig").TsParser;
const Token = @import("../common/token.zig").Token;
const Parser = @import("../common/parser.zig").Parser;
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Decl = node.Decl;
const TokenType = @import("../common/token.zig").Token.Type;
const parseresult = @import("../common/parse_result.zig");
const ParseResult = parseresult.ParseResult;
const ParseError = @import("../common/parse_error.zig").ParseError;
const allocate = @import("../common/allocate.zig");
const typeParser = @import("type_parser.zig");

const StmtTestCase = struct {
    code: []const u8,
    check: fn (value: Node) anyerror!void,

    pub fn run(comptime self: @This()) !void {
        var arena = Arena.init(std.testing.allocator);
        defer arena.deinit();

        var tsParser = TsParser.new(&arena, self.code);

        var parser = tsParser.getParser();

        const res = parser.next();
        try res.reportIfError(std.io.getStdErr().writer());
        try expect(res.isSuccess());

        try self.check(res.Success);

        const eof = parser.next();
        try eof.reportIfError(std.io.getStdErr().writer());
        try expect(eof.isSuccess());
        try expectEqual(NodeType.EOF, eof.Success.getType());
    }
};

fn eatSemi(psr: *TsParser) void {
    if (psr.lexer.token.ty == TokenType.Semi)
        _ = psr.lexer.next();
}

fn parseDecl(
    psr: *TsParser,
    comptime scoping: Decl.Scoping,
) ParseResult {
    const csr = psr.lexer.token.csr;

    const name = psr.lexer.next();
    if (name.ty != .Ident)
        return ParseResult.expected(TokenType.Ident, name);

    var declTy: ?Node = null;

    var tkn = psr.lexer.next();
    if (tkn.ty == .Colon) {
        _ = psr.lexer.next();
        const tyRes = psr.parseType();
        if (!tyRes.isSuccess())
            return tyRes;
        declTy = tyRes.Success;
        tkn = psr.lexer.token;
    }

    var expr: ?Node = null;

    if (tkn.ty == TokenType.Assign) {
        _ = psr.lexer.next();
        const exprRes = psr.parseExpr();
        if (!exprRes.isSuccess())
            return exprRes;
        expr = exprRes.Success;
        tkn = psr.lexer.token;
    }

    eatSemi(psr);

    const decl = Decl.new(scoping, name.data, declTy, expr);
    const result = makeNode(psr.getAllocator(), csr, .Decl, decl);

    return ParseResult.success(result);
}

test "can parse var, let and const declarations" {
    const Runner = struct {
        code: []const u8,
        expectedScoping: Decl.Scoping,
        expectedDeclType: ?Node,
        expectedValueIdent: ?[]const u8,

        fn run(self: @This()) !void {
            var arena = Arena.init(std.testing.allocator);
            defer arena.deinit();

            var tsParser = TsParser.new(&arena, self.code);

            var parser = tsParser.getParser();

            const res = parser.next();

            try expect(res.isSuccess());
            try expectEqual(NodeType.Decl, res.Success.getType());

            const d = res.Success.data.Decl;

            try expectEqualStrings("test", d.name);

            if (self.expectedDeclType) |t| {
                try expect(t.eql(d.ty));
            } else {
                try expect(d.ty == null);
            }

            if (self.expectedValueIdent) |i| {
                if (d.value) |value| {
                    try expectEqual(NodeType.Ident, value.getType());
                    try expectEqualStrings(i, value.data.Ident);
                } else {
                    std.debug.panic("Value should not be null", .{});
                }
            } else {
                try expect(d.value == null);
            }
        }
    };

    const numberType = makeNode(
        std.testing.allocator,
        Cursor.new(1, 11),
        NodeType.TypeName,
        "number",
    );
    defer std.testing.allocator.destroy(numberType);

    try (Runner{
        .code = "var test;",
        .expectedScoping = .Var,
        .expectedDeclType = null,
        .expectedValueIdent = null,
    }).run();

    try (Runner{
        .code = "let test;",
        .expectedScoping = .Let,
        .expectedDeclType = null,
        .expectedValueIdent = null,
    }).run();

    try (Runner{
        .code = "const test;",
        .expectedScoping = .Const,
        .expectedDeclType = null,
        .expectedValueIdent = null,
    }).run();

    try (Runner{
        .code = "var test: number;",
        .expectedScoping = .Var,
        .expectedDeclType = numberType,
        .expectedValueIdent = null,
    }).run();

    try (Runner{
        .code = "var test = someOtherVariable;",
        .expectedScoping = .Var,
        .expectedDeclType = null,
        .expectedValueIdent = "someOtherVariable",
    }).run();

    try (Runner{
        .code = "var test: number = someOtherVariable;",
        .expectedScoping = .Var,
        .expectedDeclType = numberType,
        .expectedValueIdent = "someOtherVariable",
    }).run();
}

const BranchResult = union(Type) {
    const Type = enum {
        Branch,
        ParseResult,
    };

    Branch: node.If.Branch,
    ParseResult: ParseResult,

    pub fn getType(self: BranchResult) Type {
        return @as(Type, self);
    }
};

fn parseIfBranch(psr: *TsParser) BranchResult {
    if (psr.lexer.token.ty != .If)
        return BranchResult{ .ParseResult = ParseResult.noMatch(null) };

    _ = psr.lexer.next();

    if (psr.lexer.token.ty != .LParen)
        return BranchResult{ .ParseResult = ParseResult.expected(
            "paren after 'if'",
            psr.lexer.token,
        ) };

    _ = psr.lexer.next();

    const cond = psr.parseExpr();
    if (!cond.isSuccess())
        return BranchResult{ .ParseResult = cond };

    if (psr.lexer.token.ty != .RParen)
        return BranchResult{ .ParseResult = ParseResult.expected(
            "paren after if condition",
            psr.lexer.token,
        ) };

    _ = psr.lexer.next();

    const body = psr.parseStmt();
    if (!body.isSuccess())
        return BranchResult{ .ParseResult = body };

    return BranchResult{ .Branch = node.If.Branch{
        .cond = cond.Success,
        .ifTrue = body.Success,
    } };
}

fn parseIf(psr: *TsParser) ParseResult {
    std.debug.assert(psr.lexer.token.ty == .If);

    const csr = psr.lexer.token.csr;

    var data = node.If{
        .branches = node.If.BranchList{},
        .elseBranch = null,
    };

    var branchNum: usize = 0;

    while (true) {
        var isElse: bool = undefined;
        if (psr.lexer.token.ty == .Else) {
            isElse = true;
            _ = psr.lexer.next();
        } else if (branchNum > 0) {
            break;
        } else {
            isElse = false;
        }

        branchNum += 1;

        const branch = parseIfBranch(psr);
        if (branch.getType() == .Branch) {
            data.branches.append(
                psr.getAllocator(),
                branch.Branch,
            ) catch allocate.reportAndExit();
        } else {
            const res = branch.ParseResult;
            std.debug.assert(!res.isSuccess());
            if (res.getType() == .NoMatch) {
                if (isElse) {
                    const stmt = psr.parseStmt();
                    switch (stmt.getType()) {
                        .Success => {
                            data.elseBranch = stmt.Success;
                            break;
                        },
                        .Error => return stmt,
                        .NoMatch => return ParseResult.expected(
                            "'if' after 'else'",
                            psr.lexer.token,
                        ),
                    }
                } else {
                    break;
                }
            } else {
                return res;
            }
        }
    }

    return ParseResult.success(makeNode(
        psr.getAllocator(),
        csr,
        .If,
        data,
    ));
}

test "can parse a simple if statement" {
    try (StmtTestCase{
        .code = "if (a) {}",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.If, value.getType());

                const branches = value.data.If.branches.items;
                try expectEqual(@intCast(usize, 1), branches.len);
                try expectEqual(NodeType.Ident, branches[0].cond.getType());
                try expectEqual(NodeType.Block, branches[0].ifTrue.getType());

                try expect(value.data.If.elseBranch == null);
            }
        }).check,
    }).run();
}

test "can parse an if statement with an 'else if' branch" {
    try (StmtTestCase{
        .code = "if (a) {} else if (b) {}",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.If, value.getType());

                const branches = value.data.If.branches.items;
                try expectEqual(@intCast(usize, 2), branches.len);
                try expectEqual(NodeType.Ident, branches[0].cond.getType());
                try expectEqual(NodeType.Block, branches[0].ifTrue.getType());
                try expectEqual(NodeType.Ident, branches[1].cond.getType());
                try expectEqual(NodeType.Block, branches[1].ifTrue.getType());

                try expect(value.data.If.elseBranch == null);
            }
        }).check,
    }).run();
}

test "can parse an if statement with an 'else' branch" {
    try (StmtTestCase{
        .code = "if (a) {} else {}",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.If, value.getType());

                const branches = value.data.If.branches.items;
                try expectEqual(@intCast(usize, 1), branches.len);
                try expectEqual(NodeType.Ident, branches[0].cond.getType());
                try expectEqual(NodeType.Block, branches[0].ifTrue.getType());

                const elseBranch = value.data.If.elseBranch.?;
                try expectEqual(NodeType.Block, elseBranch.getType());
            }
        }).check,
    }).run();
}

test "can parse an if statement with an 'else if' and an 'else' branch" {
    try (StmtTestCase{
        .code = "if (a) {} else if (b) {} else {}",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.If, value.getType());

                const branches = value.data.If.branches.items;
                try expectEqual(@intCast(usize, 2), branches.len);
                try expectEqual(NodeType.Ident, branches[0].cond.getType());
                try expectEqual(NodeType.Block, branches[0].ifTrue.getType());
                try expectEqual(NodeType.Ident, branches[1].cond.getType());
                try expectEqual(NodeType.Block, branches[1].ifTrue.getType());

                const elseBranch = value.data.If.elseBranch.?;
                try expectEqual(NodeType.Block, elseBranch.getType());
            }
        }).check,
    }).run();
}

fn parseSwitch(psr: *TsParser) ParseResult {
    std.debug.assert(psr.lexer.token.ty == .Switch);

    const csr = psr.lexer.token.csr;

    const lparen = psr.lexer.next();
    if (lparen.ty != .LParen)
        return ParseResult.expected(TokenType.LParen, lparen);

    const next = psr.lexer.next();
    const expr = switch (psr.parseExpr()) {
        .Success => |exp| exp,
        .Error => |err| return ParseResult.err(err),
        .NoMatch => return ParseResult.expected(
            "expression for switch statement",
            next,
        ),
    };

    if (psr.lexer.token.ty != .RParen)
        return ParseResult.expected(TokenType.RParen, psr.lexer.token);

    _ = psr.lexer.next();

    if (psr.lexer.token.ty != .LBrace)
        return ParseResult.expected(TokenType.LBrace, psr.lexer.token);

    _ = psr.lexer.next();

    const alloc = psr.getAllocator();

    const nd = makeNode(alloc, csr, .Switch, node.Switch{
        .expr = expr,
        .cases = .{},
        .default = null,
    });

    while (psr.lexer.token.ty == .Case) {
        _ = psr.lexer.next();

        const value = switch (psr.parseExpr()) {
            .Success => |val| val,
            .Error => |err| return ParseResult.err(err),
            .NoMatch => return ParseResult.expected(
                "expression after 'case'",
                psr.lexer.token,
            ),
        };

        var case = node.Switch.Case{
            .value = value,
            .stmts = node.NodeList{},
        };

        if (psr.lexer.token.ty != .Colon)
            return ParseResult.expected(TokenType.Colon, psr.lexer.token);

        _ = psr.lexer.next();

        while (psr.lexer.token.ty != .Case and
            psr.lexer.token.ty != .Default and
            psr.lexer.token.ty != .RBrace)
        {
            switch (psr.parseStmt()) {
                .Success => |stmt| case.stmts.append(
                    alloc,
                    stmt,
                ) catch allocate.reportAndExit(),
                .Error => |err| return ParseResult.err(err),
                .NoMatch => return ParseResult.expected(
                    "a statement",
                    psr.lexer.token,
                ),
            }
        }

        nd.data.Switch.cases.append(alloc, case) catch allocate.reportAndExit();
    }

    if (psr.lexer.token.ty == .Default) {
        _ = psr.lexer.next();

        if (psr.lexer.token.ty != .Colon)
            return ParseResult.expected(TokenType.Colon, psr.lexer.token);

        _ = psr.lexer.next();

        var default = node.NodeList{};

        while (psr.lexer.token.ty != .RBrace) {
            switch (psr.parseStmt()) {
                .Success => |stmt| default.append(
                    alloc,
                    stmt,
                ) catch allocate.reportAndExit(),
                .Error => |err| return ParseResult.err(err),
                .NoMatch => return ParseResult.expected(
                    "a statement",
                    psr.lexer.token,
                ),
            }
        }

        nd.data.Switch.default = default;
    }

    if (psr.lexer.token.ty != .RBrace)
        return ParseResult.expected(TokenType.RBrace, psr.lexer.token);

    _ = psr.lexer.next();

    return ParseResult.success(nd);
}

test "can parse a switch statement" {
    try (StmtTestCase{
        .code = 
        \\switch (a) {
        \\  case 1:
        \\    null;
        \\    break;
        \\  case 2:
        \\    return;
        \\  default:
        \\    null;
        \\}
        ,
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Switch, value.getType());

                const sw = value.data.Switch;
                try expectEqual(NodeType.Ident, sw.expr.getType());
                try expectEqualStrings("a", sw.expr.data.Ident);

                const cases = sw.cases.items;
                try expectEqual(@intCast(usize, 2), cases.len);

                try expectEqual(NodeType.Int, cases[0].value.getType());
                try expectEqualStrings("1", cases[0].value.data.Int);
                try expectEqual(
                    NodeType.Null,
                    cases[0].stmts.items[0].getType(),
                );
                try expectEqual(
                    NodeType.Break,
                    cases[0].stmts.items[1].getType(),
                );

                try expectEqual(NodeType.Int, cases[1].value.getType());
                try expectEqualStrings("2", cases[1].value.data.Int);
                try expectEqual(
                    NodeType.Return,
                    cases[1].stmts.items[0].getType(),
                );

                try expect(sw.default != null);
                const default = sw.default.?.items;
                try expectEqual(@intCast(usize, 1), default.len);
                try expectEqual(NodeType.Null, default[0].getType());
            }
        }).check,
    }).run();
}

fn parseForEachClause(psr: *TsParser) ?node.For.Clause {
    const save = psr.lexer.save();

    const scoping =
        Decl.Scoping.fromTokenType(psr.lexer.token.ty) catch return null;

    const name = psr.lexer.next();
    if (name.ty != .Ident) {
        psr.lexer.restore(save);
        return null;
    }

    const variant = switch (psr.lexer.next().ty) {
        .In => node.For.Clause.EachClause.Variant.In,
        .Of => node.For.Clause.EachClause.Variant.Of,
        else => {
            psr.lexer.restore(save);
            return null;
        },
    };

    _ = psr.lexer.next();

    return node.For.Clause{
        .Each = .{
            .scoping = scoping,
            .variant = variant,
            .name = name.data,
            .expr = undefined,
        },
    };
}

fn getForError(psr: *TsParser, res: ParseResult) ?ParseResult {
    return switch (res) {
        .Success => null,
        .Error => |err| ParseResult.err(err),
        .NoMatch => ParseResult.expected("statement in for loop", psr.lexer.token),
    };
}

fn parseFor(psr: *TsParser) ParseResult {
    std.debug.assert(psr.lexer.token.ty == .For);

    const csr = psr.lexer.token.csr;

    const lparen = psr.lexer.next();
    if (lparen.ty != .LParen)
        return ParseResult.expected(TokenType.LParen, lparen);

    _ = psr.lexer.next();

    var loop: node.For = undefined;

    if (parseForEachClause(psr)) |each| {
        loop.clause = each;
        switch (psr.parseExpr()) {
            .Success => |expr| loop.clause.Each.expr = expr,
            .Error => |err| return ParseResult.err(err),
            .NoMatch => return ParseResult.expected(
                "expression in for each loop",
                psr.lexer.token,
            ),
        }
    } else {
        const pre = psr.parseStmt();
        if (getForError(psr, pre)) |err|
            return err;

        const cond = psr.parseExpr();
        if (getForError(psr, cond)) |err|
            return err;

        if (psr.lexer.token.ty != .Semi)
            return ParseResult.expected(TokenType.Semi, psr.lexer.token);

        _ = psr.lexer.next();

        const post = psr.parseExpr();
        if (getForError(psr, post)) |err|
            return err;

        loop.clause = node.For.Clause{
            .CStyle = .{
                .pre = pre.Success,
                .cond = cond.Success,
                .post = post.Success,
            },
        };
    }

    if (psr.lexer.token.ty != .RParen)
        return ParseResult.expected(TokenType.RParen, psr.lexer.token);

    _ = psr.lexer.next();

    const body = psr.parseStmt();
    switch (body) {
        .Success => |bd| loop.body = bd,
        .Error => |err| return ParseResult.err(err),
        .NoMatch => return ParseResult.expected(
            "for loop body",
            psr.lexer.token,
        ),
    }

    return ParseResult.success(makeNode(psr.getAllocator(), csr, .For, loop));
}

test "can parse c-style for loop" {
    try (StmtTestCase{
        .code = "for (let i = 0; i < 4; i++) { a += i; }",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.For, value.getType());

                const loop = value.data.For;
                try expectEqual(node.For.Clause.Type.CStyle, loop.getType());

                const c = loop.clause.CStyle;
                try expectEqual(NodeType.Decl, c.pre.getType());
                try expectEqual(NodeType.BinaryOp, c.cond.getType());
                try expectEqual(NodeType.PostfixOp, c.post.getType());

                try expectEqual(NodeType.Block, loop.body.getType());
                const block = loop.body.data.Block.items;
                try expectEqual(@intCast(usize, 1), block.len);
                try expectEqual(NodeType.BinaryOp, block[0].getType());
            }
        }).check,
    }).run();
}

test "can parse for..of loop" {
    try (StmtTestCase{
        .code = "for (let a of anArray) { a += 4; }",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.For, value.getType());

                const loop = value.data.For;
                try expectEqual(node.For.Clause.Type.Each, loop.getType());

                const e = loop.clause.Each;
                try expectEqual(node.Decl.Scoping.Let, e.scoping);
                try expectEqual(
                    node.For.Clause.EachClause.Variant.Of,
                    e.variant,
                );
                try expectEqualStrings("a", e.name);
                try expectEqual(NodeType.Ident, e.expr.getType());
                try expectEqualStrings("anArray", e.expr.data.Ident);

                try expectEqual(NodeType.Block, loop.body.getType());
                const block = loop.body.data.Block.items;
                try expectEqual(@intCast(usize, 1), block.len);
                try expectEqual(NodeType.BinaryOp, block[0].getType());
            }
        }).check,
    }).run();
}

test "can parse for..in loop" {
    try (StmtTestCase{
        .code = "for (const a in anArray) { a += 4; }",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.For, value.getType());

                const loop = value.data.For;
                try expectEqual(node.For.Clause.Type.Each, loop.getType());

                const e = loop.clause.Each;
                try expectEqual(node.Decl.Scoping.Const, e.scoping);
                try expectEqual(
                    node.For.Clause.EachClause.Variant.In,
                    e.variant,
                );
                try expectEqualStrings("a", e.name);
                try expectEqual(NodeType.Ident, e.expr.getType());
                try expectEqualStrings("anArray", e.expr.data.Ident);

                try expectEqual(NodeType.Block, loop.body.getType());
                const block = loop.body.data.Block.items;
                try expectEqual(@intCast(usize, 1), block.len);
                try expectEqual(NodeType.BinaryOp, block[0].getType());
            }
        }).check,
    }).run();
}

fn parseWhile(psr: *TsParser) ParseResult {
    std.debug.assert(psr.lexer.token.ty == .While);

    const csr = psr.lexer.token.csr;

    if (psr.lexer.next().ty != .LParen)
        return ParseResult.expected("'(' after while", psr.lexer.token);

    _ = psr.lexer.next();

    const cond = psr.parseExpr();
    if (!cond.isSuccess())
        return cond;

    if (psr.lexer.token.ty != .RParen)
        return ParseResult.expected(
            "')' after while condition",
            psr.lexer.token,
        );

    _ = psr.lexer.next();

    const body = psr.parseStmt();
    if (!body.isSuccess())
        return body;

    return ParseResult.success(makeNode(
        psr.getAllocator(),
        csr,
        .While,
        node.While{
            .cond = cond.Success,
            .body = body.Success,
        },
    ));
}

test "can parse while loop" {
    try (StmtTestCase{
        .code = "while (true) {}",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.While, value.getType());

                const loop = value.data.While;
                try expectEqual(NodeType.True, loop.cond.getType());
                try expectEqual(NodeType.Block, loop.body.getType());
            }
        }).check,
    }).run();
}

fn parseDo(psr: *TsParser) ParseResult {
    std.debug.assert(psr.lexer.token.ty == .Do);

    const csr = psr.lexer.token.csr;

    _ = psr.lexer.next();

    const body = psr.parseStmt();
    if (!body.isSuccess())
        return body;

    if (psr.lexer.token.ty != .While)
        return ParseResult.expected("'while'", psr.lexer.token);

    if (psr.lexer.next().ty != .LParen)
        return ParseResult.expected("'(' after while", psr.lexer.token);

    _ = psr.lexer.next();

    const cond = psr.parseExpr();
    if (!cond.isSuccess())
        return cond;

    if (psr.lexer.token.ty != .RParen)
        return ParseResult.expected(
            "')' after do-while condition",
            psr.lexer.token,
        );

    _ = psr.lexer.next();

    eatSemi(psr);

    return ParseResult.success(makeNode(
        psr.getAllocator(),
        csr,
        .Do,
        node.Do{
            .body = body.Success,
            .cond = cond.Success,
        },
    ));
}

test "can parse do loop" {
    try (StmtTestCase{
        .code = "do {} while (true);",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Do, value.getType());

                const loop = value.data.Do;
                try expectEqual(NodeType.Block, loop.body.getType());
                try expectEqual(NodeType.True, loop.cond.getType());
            }
        }).check,
    }).run();
}

fn parseBlockStmt(psr: *TsParser) ParseResult {
    if (psr.lexer.token.ty != .LBrace)
        return ParseResult.noMatch(
            ParseError.expected("a block", psr.lexer.token),
        );

    var nd = makeNode(
        psr.getAllocator(),
        psr.lexer.token.csr,
        .Block,
        node.NodeList{},
    );

    _ = psr.lexer.next();

    while (psr.lexer.token.ty != .RBrace) {
        const stmt = psr.parseStmt();
        if (!stmt.isSuccess())
            return stmt;
        nd.data.Block.append(
            psr.getAllocator(),
            stmt.Success,
        ) catch allocate.reportAndExit();
    }

    std.debug.assert(psr.lexer.token.ty == .RBrace);

    _ = psr.lexer.next();

    return ParseResult.success(nd);
}

pub fn parseBlock(psr: *Parser) ParseResult {
    return parseBlockStmt(@fieldParentPtr(TsParser, "parser", psr));
}

test "can parse empty block" {
    try (StmtTestCase{
        .code = "{}",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Block, value.getType());
                try expectEqual(@intCast(usize, 0), value.data.Block.items.len);
            }
        }).check,
    }).run();
}

test "can parse populated block" {
    try (StmtTestCase{
        .code = "{ break; return; }",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Block, value.getType());

                const items = value.data.Block.items;
                try expectEqual(@intCast(usize, 2), items.len);
                try expectEqual(NodeType.Break, items[0].getType());
                try expectEqual(NodeType.Return, items[1].getType());
            }
        }).check,
    }).run();
}

fn parseReturn(psr: *TsParser) ParseResult {
    std.debug.assert(psr.lexer.token.ty == .Return);

    const csr = psr.lexer.token.csr;

    _ = psr.lexer.next();

    const expr = psr.parseExpr();
    if (expr.getType() == .Error)
        return expr;

    eatSemi(psr);

    return ParseResult.success(makeNode(
        psr.getAllocator(),
        csr,
        .Return,
        if (expr.isSuccess()) expr.Success else null,
    ));
}

test "can parse 'return' without expression" {
    try (StmtTestCase{
        .code = "return;",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Return, value.getType());
                try expect(value.data.Return == null);
            }
        }).check,
    }).run();
}

test "can parse 'return' with expression" {
    try (StmtTestCase{
        .code = "return 4;",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Return, value.getType());

                const expr = value.data.Return.?;
                try expectEqual(NodeType.Int, expr.getType());
                try expectEqualStrings("4", expr.data.Int);
            }
        }).check,
    }).run();
}

fn parseBreakOrContinue(
    psr: *TsParser,
    comptime ty: NodeType,
) ParseResult {
    std.debug.assert(std.mem.eql(
        u8,
        @tagName(psr.lexer.token.ty),
        @tagName(ty),
    ));

    const csr = psr.lexer.token.csr;

    _ = psr.lexer.next();

    var label: ?[]const u8 = null;

    if (psr.lexer.token.ty == .Ident) {
        label = psr.lexer.token.data;
        _ = psr.lexer.next();
    }

    eatSemi(psr);

    return ParseResult.success(makeNode(psr.getAllocator(), csr, ty, label));
}

test "can parse 'break' without label" {
    try (StmtTestCase{
        .code = "break;",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Break, value.getType());
                try expect(value.data.Break == null);
            }
        }).check,
    }).run();
}

test "can parse 'break' with label" {
    try (StmtTestCase{
        .code = "break abc;",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Break, value.getType());
                try expectEqualStrings("abc", value.data.Break.?);
            }
        }).check,
    }).run();
}

test "can parse 'continue' without label" {
    try (StmtTestCase{
        .code = "continue;",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Continue, value.getType());
                try expect(value.data.Continue == null);
            }
        }).check,
    }).run();
}

test "can parse 'continue' with label" {
    try (StmtTestCase{
        .code = "continue abc;",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Continue, value.getType());
                try expectEqualStrings("abc", value.data.Continue.?);
            }
        }).check,
    }).run();
}

fn parseThrow(psr: *TsParser) ParseResult {
    std.debug.assert(psr.lexer.token.ty == .Throw);

    const csr = psr.lexer.token.csr;

    _ = psr.lexer.next();

    const expr = psr.parseExpr();
    if (!expr.isSuccess())
        return expr;

    eatSemi(psr);

    return ParseResult.success(
        makeNode(psr.getAllocator(), csr, .Throw, expr.Success),
    );
}

test "can parse 'throw' statement" {
    try (StmtTestCase{
        .code = "throw abc;",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Throw, value.getType());
                const expr = value.data.Throw;
                try expectEqual(NodeType.Ident, expr.getType());
                try expectEqualStrings("abc", expr.data.Ident);
            }
        }).check,
    }).run();
}

fn parseTry(psr: *TsParser) ParseResult {
    std.debug.assert(psr.lexer.token.ty == .Try);

    const csr = psr.lexer.token.csr;

    _ = psr.lexer.next();

    const tryBlock = parseBlockStmt(psr);
    if (!tryBlock.isSuccess())
        return tryBlock;

    var nd = makeNode(psr.getAllocator(), csr, .Try, node.Try{
        .tryBlock = tryBlock.Success,
        .catchBlocks = node.Try.CatchList{},
        .finallyBlock = null,
    });

    while (psr.lexer.token.ty == .Catch) {
        _ = psr.lexer.next();

        if (psr.lexer.token.ty != .LParen)
            return ParseResult.expected("'(' after 'catch'", psr.lexer.token);

        _ = psr.lexer.next();

        if (psr.lexer.token.ty != .Ident)
            return ParseResult.expected(
                "identifier for caught exception",
                psr.lexer.token,
            );

        const name = psr.lexer.token.data;

        _ = psr.lexer.next();

        if (psr.lexer.token.ty != .RParen)
            return ParseResult.expected("')' after 'catch'", psr.lexer.token);

        _ = psr.lexer.next();

        const block = parseBlockStmt(psr);
        if (!block.isSuccess())
            return block;

        nd.data.Try.catchBlocks.append(psr.getAllocator(), node.Try.Catch{
            .name = name,
            .block = block.Success,
        }) catch allocate.reportAndExit();
    }

    if (psr.lexer.token.ty == .Finally) {
        _ = psr.lexer.next();

        const block = parseBlockStmt(psr);
        if (!block.isSuccess())
            return block;

        nd.data.Try.finallyBlock = block.Success;
    }

    return ParseResult.success(nd);
}

test "can parse try-catch" {
    try (StmtTestCase{
        .code = "try {} catch (e) {} catch (f) {} finally {}",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Try, value.getType());

                const t = value.data.Try;
                try expectEqual(NodeType.Block, t.tryBlock.getType());

                const catches = t.catchBlocks.items;
                try expectEqual(@intCast(usize, 2), catches.len);
                try expectEqualStrings("e", catches[0].name);
                try expectEqual(NodeType.Block, catches[0].block.getType());
                try expectEqualStrings("f", catches[1].name);
                try expectEqual(NodeType.Block, catches[1].block.getType());

                try expectEqual(NodeType.Block, t.finallyBlock.?.getType());
            }
        }).check,
    }).run();
}

fn parseExprStmt(psr: *TsParser) ParseResult {
    const expr = psr.parseExpr();
    switch (expr) {
        .Success => {
            eatSemi(psr);
            return expr;
        },
        .Error => return expr,
        .NoMatch => return ParseResult.expected("a statement", psr.lexer.token),
    }
}

test "can parse expression statements" {
    try (StmtTestCase{
        .code = "a = 3;",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.BinaryOp, value.getType());
                const op = value.data.BinaryOp;
                try expectEqual(TokenType.Assign, op.op);
                try expectEqual(NodeType.Ident, op.left.getType());
                try expectEqualStrings("a", op.left.data.Ident);
                try expectEqual(NodeType.Int, op.right.getType());
                try expectEqualStrings("3", op.right.data.Int);
            }
        }).check,
    }).run();
}

fn parseLabelled(psr: *TsParser) ParseResult {
    std.debug.assert(psr.lexer.token.ty == .Ident);

    const ctx = psr.lexer.save();

    if (psr.lexer.next().ty == .Colon) {
        _ = psr.lexer.next();

        const stmt = psr.parseStmt();
        if (!stmt.isSuccess())
            return stmt;

        return ParseResult.success(makeNode(
            psr.getAllocator(),
            ctx.token.csr,
            .Labelled,
            node.Labelled{
                .label = ctx.token.data,
                .stmt = stmt.Success,
            },
        ));
    }

    psr.lexer.restore(ctx);

    return parseExprStmt(psr);
}

test "can parse labelled statement" {
    try (StmtTestCase{
        .code = "aLabel: a = 3;",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Labelled, value.getType());
                const labelled = value.data.Labelled;
                try expectEqualStrings("aLabel", labelled.label);
                try expectEqual(NodeType.BinaryOp, labelled.stmt.getType());
            }
        }).check,
    }).run();
}

fn parseAlias(psr: *TsParser) ParseResult {
    std.debug.assert(psr.lexer.token.ty == .Type);

    const csr = psr.lexer.token.csr;

    const name = psr.lexer.next();
    if (name.ty != .Ident)
        return ParseResult.expected("name for type alias", name);

    _ = psr.lexer.next();

    if (psr.lexer.token.ty != .Assign)
        return ParseResult.expected(Token.Type.Assign, psr.lexer.token);

    _ = psr.lexer.next();

    const value = psr.parseType();
    if (value.isError()) {
        return value;
    } else if (value.isNoMatch()) {
        return ParseResult.expected("name for type alias", psr.lexer.token);
    }

    eatSemi(psr);

    return ParseResult.success(makeNode(
        psr.getAllocator(),
        csr,
        .Alias,
        node.Alias.new(name.data, value.Success),
    ));
}

test "can parse type alias statement" {
    try (StmtTestCase{
        .code = "type IntOrString = int | string;",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Alias, value.getType());

                const alias = value.data.Alias;
                try expectEqualStrings("IntOrString", alias.name);
                try expectEqual(NodeType.UnionType, alias.value.getType());

                const types = alias.value.data.UnionType.items;
                try expectEqual(@intCast(usize, 2), types.len);
                try expectEqual(NodeType.TypeName, types[0].getType());
                try expectEqualStrings("int", types[0].data.TypeName);
                try expectEqual(NodeType.TypeName, types[1].getType());
                try expectEqualStrings("string", types[1].data.TypeName);
            }
        }).check,
    }).run();
}

fn parseInterface(psr: *TsParser) ParseResult {
    std.debug.assert(psr.lexer.token.ty == .Interface);

    const csr = psr.lexer.token.csr;

    const name = psr.lexer.next();
    if (name.ty != .Ident)
        return ParseResult.expected("name for interface", name);

    _ = psr.lexer.next();

    var ty = switch (typeParser.parseInlineInterfaceType(psr)) {
        .Success => |result| result,
        else => |result| return result,
    };

    ty.csr = csr;
    ty.data.InterfaceType.name = name.data;

    return ParseResult.success(ty);
}

test "can parse interface statement" {
    try (StmtTestCase{
        .code = "interface AnInterface { a: number, b: string }",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.InterfaceType, value.getType());

                const in = value.data.InterfaceType;
                try expectEqualStrings("AnInterface", in.name.?);
                try expectEqual(@intCast(usize, 2), in.members.items.len);

                const a = in.members.items[0];
                try expectEqualStrings("a", a.name);
                try expectEqual(NodeType.TypeName, a.ty.getType());
                try expectEqualStrings("number", a.ty.data.TypeName);

                const b = in.members.items[1];
                try expectEqualStrings("b", b.name);
                try expectEqual(NodeType.TypeName, b.ty.getType());
                try expectEqualStrings("string", b.ty.data.TypeName);
            }
        }).check,
    }).run();
}

fn parseMemberFunction(
    psr: *TsParser,
    csr: Cursor,
    visibility: node.Visibility,
    isStatic: bool,
    name: []const u8,
) ParseResult {
    std.debug.assert(psr.lexer.token.ty == .LParen);

    const res = psr.parseLongFunction(csr, name);
    switch (res) {
        .Success => |n| {
            std.debug.assert(n.getType() == .Function);
            return ParseResult.success(makeNode(
                psr.getAllocator(),
                csr,
                .ClassTypeMember,
                node.ClassTypeMember{
                    .isStatic = isStatic,
                    .visibility = visibility,
                    .data = .{
                        .Func = n.data.Function,
                    },
                },
            ));
        },
        .NoMatch => return ParseResult.errMessage(
            csr,
            "Invalid class member function",
        ),
        .Error => return res,
    }
}

fn parseClassMember(psr: *TsParser) ParseResult {
    const csr = psr.lexer.token.csr;

    var visibility = node.Visibility.Public;
    var isStatic = false;
    var isReadOnly = false;

    modifiers: while (true) {
        switch (psr.lexer.token.ty) {
            .Public => visibility = .Public,
            .Protected => visibility = .Protected,
            .Private => visibility = .Private,
            .Static => isStatic = true,
            .ReadOnly => isReadOnly = true,
            else => break :modifiers,
        }

        _ = psr.lexer.next();
    }

    if (psr.lexer.token.ty != .Ident)
        return ParseResult.expected("a class member", psr.lexer.token);

    const name = psr.lexer.token.data;

    _ = psr.lexer.next();

    if (psr.lexer.token.ty == .LParen) {
        if (isReadOnly)
            return ParseResult.errMessage(
                csr,
                "Class member function cannot be marked as 'readonly'",
            );
        return parseMemberFunction(psr, csr, visibility, isStatic, name);
    }

    var ty: ?Node = null;
    if (psr.lexer.token.ty == .Colon) {
        _ = psr.lexer.next();
        const tyRes = psr.parseType();
        switch (tyRes) {
            .Success => |success| ty = success,
            .Error => return tyRes,
            .NoMatch => return ParseResult.expected(
                "a type for class member after ':'",
                psr.lexer.token,
            ),
        }
    }

    var value: ?Node = null;
    if (psr.lexer.token.ty == .Assign) {
        _ = psr.lexer.next();
        const exprRes = psr.parseExpr();
        switch (exprRes) {
            .Success => |success| value = success,
            .Error => return exprRes,
            .NoMatch => return ParseResult.expected(
                "a value for class member after '='",
                psr.lexer.token,
            ),
        }
    }

    eatSemi(psr);

    return ParseResult.success(makeNode(
        psr.getAllocator(),
        csr,
        .ClassTypeMember,
        node.ClassTypeMember{
            .isStatic = isStatic,
            .visibility = visibility,
            .data = .{
                .Var = .{
                    .isReadOnly = isReadOnly,
                    .name = name,
                    .ty = ty,
                    .value = value,
                },
            },
        },
    ));
}

fn parseClass(psr: *TsParser) ParseResult {
    std.debug.assert(psr.lexer.token.ty == .Class);

    const csr = psr.lexer.token.csr;

    const name = psr.lexer.next();
    if (name.ty != .Ident)
        return ParseResult.expected("name for class", name);

    var extends: ?[]const u8 = null;

    if (psr.lexer.next().ty == .Extends) {
        _ = psr.lexer.next();
        if (psr.lexer.token.ty != .Ident) {
            return ParseResult.expected(
                "name of class to extend",
                psr.lexer.token,
            );
        }
        extends = psr.lexer.token.data;
        _ = psr.lexer.next();
    }

    if (psr.lexer.token.ty != .LBrace)
        return ParseResult.expected("opening '{' in class", psr.lexer.token);

    _ = psr.lexer.next();

    var class = makeNode(
        psr.getAllocator(),
        csr,
        .ClassType,
        node.ClassType.new(name.data, extends),
    );

    members: while (psr.lexer.token.ty != .RBrace) {
        const res = parseClassMember(psr);
        switch (res) {
            .Success => |member| class.data.ClassType.members.append(
                psr.getAllocator(),
                member,
            ) catch allocate.reportAndExit(),
            .Error => return res,
            .NoMatch => break :members,
        }
    }

    if (psr.lexer.token.ty != .RBrace)
        return ParseResult.expected("closing '}' after class", psr.lexer.token);

    _ = psr.lexer.next();

    return ParseResult.success(class);
}

test "can parse empty class statement" {
    try (StmtTestCase{
        .code = "class MyClass {}",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.ClassType, value.getType());

                const cls = value.data.ClassType;
                try expectEqualStrings("MyClass", cls.name);
                try expect(cls.extends == null);
            }
        }).check,
    }).run();
}

test "can parse empty class statement with 'extends'" {
    try (StmtTestCase{
        .code = "class MyClass extends SomeOtherClass {}",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.ClassType, value.getType());

                const cls = value.data.ClassType;
                try expectEqualStrings("MyClass", cls.name);
                try expect(cls.extends != null);
                try expectEqualStrings("SomeOtherClass", cls.extends.?);
            }
        }).check,
    }).run();
}

test "can parse a class with a property" {
    try (StmtTestCase{
        .code = "class MyClass { static readonly public a: number = 0; }",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.ClassType, value.getType());

                const cls = value.data.ClassType;
                try expectEqualStrings("MyClass", cls.name);
                try expect(cls.extends == null);

                const members = cls.members.items;
                try expectEqual(@intCast(usize, 1), members.len);

                try expect(members[0].getType() == .ClassTypeMember);
                const member = members[0].data.ClassTypeMember;
                try expectEqual(true, member.isStatic);
                try expectEqual(node.Visibility.Public, member.visibility);
                try expect(member.getType() == .Var);
                const v = member.data.Var;
                try expectEqual(true, v.isReadOnly);
                try expectEqualStrings("a", v.name);
                try expect(v.ty != null);
                try expectEqual(NodeType.TypeName, v.ty.?.getType());
                try expectEqualStrings("number", v.ty.?.data.TypeName);
                try expect(v.value != null);
                try expectEqual(NodeType.Int, v.value.?.getType());
                try expectEqualStrings("0", v.value.?.data.Int);
            }
        }).check,
    }).run();
}

test "can parse a class with a member function" {
    try (StmtTestCase{
        .code = "class MyClass { private static func(a: number) {} }",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.ClassType, value.getType());

                const cls = value.data.ClassType;
                try expectEqualStrings("MyClass", cls.name);
                try expect(cls.extends == null);

                const members = cls.members.items;
                try expectEqual(@intCast(usize, 1), members.len);

                try expect(members[0].getType() == .ClassTypeMember);
                const member = members[0].data.ClassTypeMember;
                _ = member;
                // try expectEqual(true, member.isStatic);
                // try expectEqual(true, member.isReadOnly);
                // try expectEqual(node.Visibility.Public, member.visibility);
                // try expectEqualStrings("a", member.name);
                // try expect(member.ty != null);
                // try expectEqual(NodeType.TypeName, member.ty.?.getType());
                // try expectEqualStrings("number", member.ty.?.data.TypeName);
                // try expect(member.value != null);
                // try expectEqual(NodeType.Int, member.value.?.getType());
                // try expectEqualStrings("0", member.value.?.data.Int);
            }
        }).check,
    }).run();
}

fn parseStmtInternal(psr: *TsParser) ParseResult {
    while (psr.lexer.token.ty == .Semi)
        _ = psr.lexer.next();

    return switch (psr.lexer.token.ty) {
        .Var => parseDecl(psr, .Var),
        .Let => parseDecl(psr, .Let),
        .Const => parseDecl(psr, .Const),
        .Return => parseReturn(psr),
        .If => parseIf(psr),
        .Switch => parseSwitch(psr),
        .While => parseWhile(psr),
        .For => parseFor(psr),
        .Do => parseDo(psr),
        .LBrace => parseBlockStmt(psr),
        .Break => parseBreakOrContinue(psr, .Break),
        .Continue => parseBreakOrContinue(psr, .Continue),
        .Throw => parseThrow(psr),
        .Try => parseTry(psr),
        .Type => parseAlias(psr),
        .Interface => parseInterface(psr),
        .Class => parseClass(psr),
        .EOF => ParseResult.success(makeNode(
            psr.getAllocator(),
            psr.lexer.token.csr,
            .EOF,
            {},
        )),
        .Ident => parseLabelled(psr),
        else => parseExprStmt(psr),
    };
}

pub fn parseStmt(psr: *Parser) ParseResult {
    return parseStmtInternal(@fieldParentPtr(TsParser, "parser", psr));
}

test "can parse end-of-file" {
    try (StmtTestCase{
        .code = "",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.EOF, value.getType());
            }
        }).check,
    }).run();
}

test "can skip empty statements" {
    try (StmtTestCase{
        .code = "; ;; break;",
        .check = (struct {
            fn check(value: Node) anyerror!void {
                try expectEqual(NodeType.Break, value.getType());
            }
        }).check,
    }).run();
}
