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
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const ParseResult = @import("parse_result.zig").ParseResult;
const ParseError = @import("parse_error.zig").ParseError;
const Cursor = @import("cursor.zig").Cursor;
const node = @import("node.zig");

pub const Parser = struct {
    pub const Error = Allocator.Error;

    callbacks: struct {
        currentCursor: fn (self: *Parser) Cursor,
        parseExpr: fn (self: *Parser) Parser.Error!ParseResult,
        parseType: fn (self: *Parser) Parser.Error!ParseResult,
        parseBlock: fn (self: *Parser) Parser.Error!ParseResult,
        parseStmt: fn (self: *Parser) Parser.Error!ParseResult,
    },

    pub fn currentCursor(self: *Parser) Cursor {
        return self.callbacks.currentCursor(self);
    }

    pub fn parseExpr(self: *Parser) Parser.Error!ParseResult {
        return self.callbacks.parseExpr(self);
    }

    pub fn parseType(self: *Parser) Parser.Error!ParseResult {
        return self.callbacks.parseType(self);
    }

    pub fn parseBlock(self: *Parser) Parser.Error!ParseResult {
        return self.callbacks.parseBlock(self);
    }

    pub fn parseStmt(self: *Parser) Parser.Error!ParseResult {
        return self.callbacks.parseStmt(self);
    }

    pub fn next(self: *Parser) Parser.Error!ParseResult {
        return self.parseStmt();
    }

    pub fn getAst(self: *Parser, arena: *Arena) Parser.Error!ParseResult {
        var alloc = &arena.allocator;

        var nd = try node.makeNode(
            alloc,
            Cursor.new(1, 1),
            .Program,
            node.NodeList{},
        );

        while (true) {
            const res = try self.next();

            switch (res) {
                .Success => |node| {
                    switch (node.getType()) {
                        .EOF => return ParseResult.success(nd),
                        else => try nd.data.Program.append(alloc, node),
                    }
                },
                .Error => |err| return ParseResult.err(err),
                .NoMatch => |err| {
                    const theError = if (err) |perr|
                        perr
                    else
                        ParseError.message(
                            self.currentCursor(),
                            "Expected a top-level statement",
                        );

                    return ParseResult.err(theError);
                },
            }
        }
    }
};
