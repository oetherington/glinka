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
const Compiler = @import("compiler.zig").Compiler;
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const Type = @import("../common/types/type.zig").Type;
const ContextError = @import("errors/context_error.zig").ContextError;
const CompileError = @import("errors/compile_error.zig").CompileError;
const CompilerTestCase = @import("compiler_test_case.zig").CompilerTestCase;
const allocate = @import("../common/allocate.zig");

fn processCStyleClause(
    cmp: *Compiler,
    clause: node.For.Clause.CStyleClause,
) void {
    cmp.processNode(clause.pre);
    cmp.processNode(clause.cond);
    cmp.processNode(clause.post);
}

fn processEachClause(
    cmp: *Compiler,
    clause: node.For.Clause.EachClause,
) void {
    _ = cmp;
    _ = clause;
    // TODO
    // For each loops should be implemented once objects are implemented as
    // they work on the 'iterable' property.
    // See typescriptlang.org/docs/handbook/iterators-and-generators.html
}

pub fn processFor(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == .For);

    cmp.pushScope();

    const loop = nd.data.For;

    switch (loop.clause) {
        .CStyle => |clause| processCStyleClause(cmp, clause),
        .Each => |clause| processEachClause(cmp, clause),
    }

    cmp.scope.ctx = .Loop;
    cmp.processNode(loop.body);

    cmp.popScope();
}

test "can compile c-style 'for' statements" {
    try (CompilerTestCase{
        .code = "for (let i = 0; i < 10; i--) i += 2;",
    }).run();
}

pub fn processWhile(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == .While);

    const loop = nd.data.While;

    _ = cmp.inferExprType(loop.cond);

    cmp.pushScope();
    cmp.scope.ctx = .Loop;
    cmp.processNode(loop.body);
    cmp.popScope();
}

test "can compile 'while' statements" {
    try (CompilerTestCase{
        .code = "while (true) var a = 6;",
    }).run();
}

pub fn processDo(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == .Do);

    const loop = nd.data.Do;

    cmp.scope.ctx = .Loop;
    cmp.processNode(loop.body);
    cmp.scope.ctx = null;

    _ = cmp.inferExprType(loop.cond);
}

test "can compile 'do' statements" {
    try (CompilerTestCase{
        .code = "do var x = 3; while (true);",
    }).run();
}

pub fn processBreak(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == .Break);

    if (!cmp.scope.isInContext(.Loop) and !cmp.scope.isInContext(.Switch))
        cmp.errors.append(CompileError.contextError(ContextError.new(
            nd.csr,
            "Break",
            "a loop",
        ))) catch allocate.reportAndExit();
}

test "can compile 'break' statements in a loop" {
    try (CompilerTestCase{
        .code = "while (true) break;",
    }).run();
}

// TODO: Test case where break is inside a switch statement
test "'break' must be inside a loop" {
    try (CompilerTestCase{
        .code = "break;",
        .check = (struct {
            pub fn check(self: CompilerTestCase, cmp: Compiler) anyerror!void {
                try self.expectEqual(@intCast(usize, 1), cmp.errors.count());
                const err = cmp.getError(0);
                try self.expectEqual(
                    CompileError.Type.ContextError,
                    err.getType(),
                );
                try self.expectEqualStrings(
                    "Break",
                    err.ContextError.found,
                );
                try self.expectEqualStrings(
                    "a loop",
                    err.ContextError.expectedContext,
                );
            }
        }).check,
    }).run();
}

pub fn processContinue(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == .Continue);

    if (!cmp.scope.isInContext(.Loop))
        cmp.errors.append(CompileError.contextError(ContextError.new(
            nd.csr,
            "Continue",
            "a loop",
        ))) catch allocate.reportAndExit();
}

test "can compile 'continue' statements" {
    try (CompilerTestCase{
        .code = "while (true) continue;",
    }).run();
}

test "'continue' must be inside a loop" {
    try (CompilerTestCase{
        .code = "continue;",
        .check = (struct {
            pub fn check(self: CompilerTestCase, cmp: Compiler) anyerror!void {
                try self.expectEqual(@intCast(usize, 1), cmp.errors.count());
                const err = cmp.getError(0);
                try self.expectEqual(
                    CompileError.Type.ContextError,
                    err.getType(),
                );
                try self.expectEqualStrings(
                    "Continue",
                    err.ContextError.found,
                );
                try self.expectEqualStrings(
                    "a loop",
                    err.ContextError.expectedContext,
                );
            }
        }).check,
    }).run();
}
