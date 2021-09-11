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
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const Lexer = @import("lexer.zig").Lexer;
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Decl = node.Decl;
const TokenType = @import("token.zig").TokenType;
const parseresult = @import("parse_result.zig");
const ParseResult = parseresult.ParseResult;
const ParseError = parseresult.ParseError;
const exprParser = @import("expr_parser.zig");
const stmtParser = @import("stmt_parser.zig");

pub const Parser = struct {
    pub const Error = Allocator.Error;

    arena: Arena,
    lexer: Lexer,

    pub fn new(alloc: *Allocator, code: []const u8) Parser {
        var lexer = Lexer.new(code);
        _ = lexer.next();

        return Parser{
            .arena = Arena.init(alloc),
            .lexer = lexer,
        };
    }

    pub fn deinit(self: Parser) void {
        self.arena.deinit();
    }

    pub fn getAllocator(self: *Parser) *Allocator {
        return &self.arena.allocator;
    }

    pub fn parseExpr(self: *Parser) Parser.Error!ParseResult {
        return exprParser.parseExpr(self);
    }

    pub fn parseType(self: *Parser) Parser.Error!ParseResult {
        switch (self.lexer.token.ty) {
            .Ident => {
                const nd = try makeNode(
                    self.getAllocator(),
                    self.lexer.token.csr,
                    NodeType.TypeName,
                    self.lexer.token.data,
                );

                _ = self.lexer.next();

                return ParseResult.success(nd);
            },
            else => return ParseResult.noMatch(null),
        }
    }

    pub fn parseStmt(self: *Parser) Parser.Error!ParseResult {
        return stmtParser.parseStmt(self);
    }

    pub fn next(self: *Parser) Parser.Error!ParseResult {
        return self.parseStmt();
    }
};

test "parser can be initialized" {
    const code: []const u8 = "some sample code";
    var parser = Parser.new(std.testing.allocator, code);
    defer parser.deinit();
    try expectEqualSlices(u8, code, parser.lexer.code);
}
