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
const Config = @import("../../common/config.zig").Config;
const Cursor = @import("../../common/cursor.zig").Cursor;
const NopBackend = @import("../compiler_test_case.zig").NopBackend;
const Compiler = @import("../compiler.zig").Compiler;
const Type = @import("../../common/types/type.zig").Type;
const node = @import("../../common/node.zig");
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Scope = @import("../scope.zig").Scope;
const TypeBook = @import("../typebook.zig").TypeBook;
const InferResult = @import("infer_result.zig").InferResult;
const inferExprType = @import("inferrer.zig").inferExprType;

pub const InferTestCase = struct {
    expectedTy: ?Type.Type = null,
    check: ?fn (
        scope: *Scope,
        typebook: *TypeBook,
        res: InferResult,
    ) anyerror!void = null,
    setup: ?fn (
        scope: *Scope,
        typebook: *TypeBook,
    ) anyerror!void = null,

    pub fn expectSuccess(res: InferResult) !void {
        if (res.getType() != .Success)
            try res.Error.report(std.io.getStdErr().writer());
        try expectEqual(InferResult.Success, res.getType());
    }

    pub fn run(
        self: InferTestCase,
        comptime nodeType: NodeType,
        nodeData: anytype,
    ) !void {
        const config = Config{};
        var backend = NopBackend.new();

        var compiler = Compiler.new(
            std.testing.allocator,
            &config,
            &backend.backend,
        );
        defer compiler.deinit();

        if (self.setup) |setup|
            try setup(compiler.scope, compiler.typebook);

        const nd = makeNode(
            std.testing.allocator,
            Cursor.new(6, 9),
            nodeType,
            nodeData,
        );
        defer std.testing.allocator.destroy(nd);

        const res = inferExprType(&compiler, nd, .None);

        if (res.getType() != .Success and self.expectedTy != null)
            try res.Error.report(std.io.getStdErr().writer());

        if (self.expectedTy) |expectedTy| {
            try expectEqual(InferResult.Success, res.getType());
            try expectEqual(expectedTy, res.Success.getType());
            try expect(nd.ty != null);
            try expectEqual(expectedTy, nd.ty.?.getType());
        }

        if (self.check) |check|
            try check(compiler.scope, compiler.typebook, res);
    }
};
