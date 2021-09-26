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
const Arena = std.heap.ArenaAllocator;
const Compiler = @import("compiler.zig").Compiler;
const Backend = @import("../common/backend.zig").Backend;
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const Config = @import("../common/config.zig").Config;
const TsParser = @import("../frontend/ts_parser.zig").TsParser;

const NopBackend = struct {
    backend: Backend,

    pub fn new() NopBackend {
        var callbacks: Backend.Callbacks = undefined;

        inline for (std.meta.fields(Backend.Callbacks)) |field| {
            @field(callbacks, field.name) = switch (field.field_type) {
                Backend.Callback => NopBackend.nopCallback,
                Backend.NodeCallback => NopBackend.nopNodeCallback,
                else => @compileError("Unimplemented NOP backend callback"),
            };
        }

        return NopBackend{
            .backend = .{
                .callbacks = callbacks,
            },
        };
    }

    fn nopCallback(be: *Backend) Backend.Error!void {
        _ = be;
    }

    fn nopNodeCallback(be: *Backend, nd: Node) Backend.Error!void {
        _ = be;
        _ = nd;
    }
};

pub const CompilerTestCase = struct {
    const Error = error{ TestUnexpectedResult, TestExpectedEqual };

    code: []const u8,
    check: fn (
        case: CompilerTestCase,
        cmp: Compiler,
    ) anyerror!void = CompilerTestCase.checkNoErrors,

    pub fn run(comptime self: @This()) !void {
        var arena = Arena.init(std.testing.allocator);
        defer arena.deinit();

        var tsParser = TsParser.new(&arena, self.code);

        var parser = tsParser.getParser();

        const res = parser.getAst(&arena);
        try res.reportIfError(std.io.getStdErr().writer());
        try self.expect(res.isSuccess());
        try self.expectEqual(NodeType.Program, res.Success.getType());

        const config = Config{};

        var backend = NopBackend.new();

        var compiler = try Compiler.new(
            std.testing.allocator,
            &config,
            &backend.backend,
        );
        defer compiler.deinit();

        try compiler.compileProgramNode(res.Success);

        try self.check(self, compiler);
    }

    pub fn expect(self: CompilerTestCase, ok: bool) Error!void {
        _ = self;
        try std.testing.expect(ok);
    }

    pub fn expectEqual(
        self: CompilerTestCase,
        expected: anytype,
        actual: @TypeOf(expected),
    ) Error!void {
        _ = self;
        try std.testing.expectEqual(expected, actual);
    }

    pub fn expectEqualStrings(
        self: CompilerTestCase,
        expected: []const u8,
        actual: []const u8,
    ) Error!void {
        _ = self;
        try std.testing.expectEqualStrings(expected, actual);
    }

    pub fn checkNoErrors(self: CompilerTestCase, cmp: Compiler) anyerror!void {
        try self.expect(!cmp.hasErrors());
    }
};
