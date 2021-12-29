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
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const ParseResult = @import("parse_result.zig").ParseResult;
const ParseError = @import("parse_error.zig").ParseError;
const Cursor = @import("cursor.zig").Cursor;
const node = @import("node.zig");
const allocate = @import("allocate.zig");

pub const Parser = struct {
    callbacks: struct {
        currentCursor: fn (self: *Parser) Cursor,
        parseExpr: fn (self: *Parser) ParseResult,
        parseType: fn (self: *Parser) ParseResult,
        parseBlock: fn (self: *Parser) ParseResult,
        parseStmt: fn (self: *Parser) ParseResult,
    },

    pub fn currentCursor(self: *Parser) Cursor {
        return self.callbacks.currentCursor(self);
    }

    pub fn parseExpr(self: *Parser) ParseResult {
        return self.callbacks.parseExpr(self);
    }

    pub fn parseType(self: *Parser) ParseResult {
        return self.callbacks.parseType(self);
    }

    pub fn parseBlock(self: *Parser) ParseResult {
        return self.callbacks.parseBlock(self);
    }

    pub fn parseStmt(self: *Parser) ParseResult {
        return self.callbacks.parseStmt(self);
    }

    pub fn next(self: *Parser) ParseResult {
        return self.parseStmt();
    }

    pub fn getAst(self: *Parser, arena: *Arena) ParseResult {
        var alloc = arena.allocator();

        var nd = node.makeNode(
            alloc,
            Cursor.new(1, 1),
            .Program,
            node.NodeList{},
        );

        while (true) {
            const res = self.next();

            switch (res) {
                .Success => |node| {
                    switch (node.getType()) {
                        .EOF => return ParseResult.success(nd),
                        else => nd.data.Program.append(
                            alloc,
                            node,
                        ) catch allocate.reportAndExit(),
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
