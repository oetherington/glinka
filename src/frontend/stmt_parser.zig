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
const Allocator = std.mem.Allocator;
const Parser = @import("parser.zig").Parser;
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Decl = node.Decl;
const TokenType = @import("token.zig").Token.Type;
const parseresult = @import("parse_result.zig");
const ParseResult = parseresult.ParseResult;
const ParseError = parseresult.ParseError;

const StmtTestCase = struct {
    code: []const u8,
    check: fn (value: Node) anyerror!void,

    pub fn run(comptime self: @This()) !void {
        var parser = Parser.new(std.testing.allocator, self.code);
        defer parser.deinit();

        const res = try parser.next();
        try res.reportIfError(std.io.getStdErr().writer());
        try expect(res.isSuccess());

        try self.check(res.Success);

        const eof = try parser.next();
        try expect(eof.isSuccess());
        try expectEqual(NodeType.EOF, eof.Success.getType());
    }
};

fn parseDecl(
    psr: *Parser,
    comptime scoping: Decl.Scoping,
) Parser.Error!ParseResult {
    const csr = psr.lexer.token.csr;

    const name = psr.lexer.next();
    if (name.ty != .Ident)
        return ParseResult.expected(TokenType.Ident, name);

    var declTy: ?Node = null;

    var tkn = psr.lexer.next();
    if (tkn.ty == .Colon) {
        _ = psr.lexer.next();
        const tyRes = try psr.parseType();
        if (!tyRes.isSuccess())
            return tyRes;
        declTy = tyRes.Success;
        tkn = psr.lexer.token;
    }

    var expr: ?Node = null;

    if (tkn.ty == TokenType.Assign) {
        _ = psr.lexer.next();
        const exprRes = try psr.parseExpr();
        if (!exprRes.isSuccess())
            return exprRes;
        expr = exprRes.Success;
        tkn = psr.lexer.token;
    }

    if (tkn.ty != TokenType.Semi)
        return ParseResult.expected(TokenType.Semi, psr.lexer.token);

    _ = psr.lexer.next();

    const decl = Decl.new(scoping, name.data, declTy, expr);
    const result = try makeNode(psr.getAllocator(), csr, .Decl, decl);

    return ParseResult.success(result);
}

test "can parse end-of-file" {
    var parser = Parser.new(std.testing.allocator, "");
    defer parser.deinit();

    const res = try parser.next();

    try expect(res.isSuccess());
    try expectEqual(NodeType.EOF, res.Success.getType());
}

test "can parse var, let and const declarations" {
    const Runner = struct {
        code: []const u8,
        expectedScoping: Decl.Scoping,
        expectedDeclType: ?Node,
        expectedValueIdent: ?[]const u8,

        fn run(self: @This()) !void {
            var parser = Parser.new(std.testing.allocator, self.code);
            defer parser.deinit();

            const res = try parser.next();

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

    const numberType = try makeNode(
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

fn parseIfBranch(psr: *Parser) Parser.Error!BranchResult {
    if (psr.lexer.token.ty != .If)
        return BranchResult{ .ParseResult = ParseResult.noMatch(null) };

    _ = psr.lexer.next();

    if (psr.lexer.token.ty != .LParen)
        return BranchResult{ .ParseResult = ParseResult.expected(
            "paren after 'if'",
            psr.lexer.token,
        ) };

    _ = psr.lexer.next();

    const cond = try psr.parseExpr();
    if (!cond.isSuccess())
        return BranchResult{ .ParseResult = cond };

    if (psr.lexer.token.ty != .RParen)
        return BranchResult{ .ParseResult = ParseResult.expected(
            "paren after if condition",
            psr.lexer.token,
        ) };

    _ = psr.lexer.next();

    const body = try psr.parseStmt();
    if (!body.isSuccess())
        return BranchResult{ .ParseResult = body };

    return BranchResult{ .Branch = node.If.Branch{
        .cond = cond.Success,
        .ifTrue = body.Success,
    } };
}

fn parseIf(psr: *Parser) Parser.Error!ParseResult {
    std.debug.assert(psr.lexer.token.ty == .If);

    const csr = psr.lexer.token.csr;

    var data = node.If{
        .branches = node.If.BranchList{},
        .elseBranch = null,
    };

    while (true) {
        var isElse: bool = undefined;
        if (psr.lexer.token.ty == .Else) {
            isElse = true;
            _ = psr.lexer.next();
        } else {
            isElse = false;
        }

        const branch = try parseIfBranch(psr);
        if (branch.getType() == .Branch) {
            try data.branches.append(psr.getAllocator(), branch.Branch);
        } else {
            const res = branch.ParseResult;
            std.debug.assert(!res.isSuccess());
            if (res.getType() == .NoMatch) {
                if (isElse) {
                    const stmt = try psr.parseStmt();
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

    return ParseResult.success(try makeNode(
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

pub fn parseBlock(psr: *Parser) Parser.Error!ParseResult {
    if (psr.lexer.token.ty != .LBrace)
        return ParseResult.noMatch(
            ParseError.expected("a block", psr.lexer.token),
        );

    var nd = try makeNode(
        psr.getAllocator(),
        psr.lexer.token.csr,
        .Block,
        node.NodeList{},
    );

    _ = psr.lexer.next();

    while (psr.lexer.token.ty != .RBrace) {
        const stmt = try psr.parseStmt();
        if (!stmt.isSuccess())
            return stmt;
        try nd.data.Block.append(psr.getAllocator(), stmt.Success);
    }

    std.debug.assert(psr.lexer.token.ty == .RBrace);

    _ = psr.lexer.next();

    return ParseResult.success(nd);
}

test "can parse empty block" {
    var parser = Parser.new(std.testing.allocator, "{}");
    defer parser.deinit();
    const res = try parser.next();
    try expect(res.isSuccess());
    try expectEqual(NodeType.Block, res.Success.getType());
    try expectEqual(@intCast(usize, 0), res.Success.data.Block.items.len);
}

pub fn parseStmt(psr: *Parser) Parser.Error!ParseResult {
    return switch (psr.lexer.token.ty) {
        .Var => parseDecl(psr, .Var),
        .Let => parseDecl(psr, .Let),
        .Const => parseDecl(psr, .Const),
        .If => parseIf(psr),
        .LBrace => parseBlock(psr),
        .EOF => ParseResult.success(try makeNode(
            psr.getAllocator(),
            psr.lexer.token.csr,
            .EOF,
            {},
        )),
        else => ParseResult.expected("a statement", psr.lexer.token),
    };
}
