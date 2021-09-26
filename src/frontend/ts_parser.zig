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
const Arena = std.heap.ArenaAllocator;
const Parser = @import("../common/parser.zig").Parser;
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Decl = node.Decl;
const TokenType = @import("../common/token.zig").TokenType;
const parseresult = @import("../common/parse_result.zig");
const ParseResult = parseresult.ParseResult;
const ParseError = @import("../common/parse_error.zig").ParseError;
const exprParser = @import("expr_parser.zig");
const typeParser = @import("type_parser.zig");
const stmtParser = @import("stmt_parser.zig");
const Lexer = @import("lexer.zig").Lexer;

pub const TsParser = struct {
    pub const Error = Allocator.Error;

    arena: *Arena,
    lexer: Lexer,
    parser: Parser,

    pub fn new(arena: *Arena, code: []const u8) TsParser {
        var lexer = Lexer.new(code);
        _ = lexer.next();

        return TsParser{
            .arena = arena,
            .lexer = lexer,
            .parser = Parser{
                .callbacks = .{
                    .currentCursor = TsParser.currentCursor,
                    .parseExpr = exprParser.parseExpr,
                    .parseType = typeParser.parseType,
                    .parseBlock = stmtParser.parseBlock,
                    .parseStmt = stmtParser.parseStmt,
                },
            },
        };
    }

    pub fn getAllocator(self: *TsParser) *Allocator {
        return &self.arena.allocator;
    }

    pub fn getParser(self: *TsParser) *Parser {
        return &self.parser;
    }

    pub fn currentCursor(psr: *Parser) Cursor {
        const self = @fieldParentPtr(TsParser, "parser", psr);
        return self.lexer.token.csr;
    }

    pub fn parseExpr(self: *TsParser) ParseResult {
        return exprParser.parseExpr(self.getParser());
    }

    pub fn parseType(self: *TsParser) ParseResult {
        return typeParser.parseType(self.getParser());
    }

    pub fn parseBlock(self: *TsParser) ParseResult {
        return stmtParser.parseBlock(self.getParser());
    }

    pub fn parseStmt(self: *TsParser) ParseResult {
        return stmtParser.parseStmt(self.getParser());
    }

    pub fn next(self: *TsParser) ParseResult {
        return self.parseStmt();
    }
};

test "TsParser can be initialized" {
    const code: []const u8 = "some sample code";
    var arena = Arena.init(std.testing.allocator);
    defer arena.deinit();
    var parser = TsParser.new(&arena, code);
    try expectEqualStrings(code, parser.lexer.code);
}
