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
const expectEqualStrings = std.testing.expectEqualStrings;
const Allocator = std.mem.Allocator;
const Backend = @import("../../common/backend.zig").Backend;
const Cursor = @import("../../common/cursor.zig").Cursor;
const WriteContext = @import("../../common/writer.zig").WriteContext;
const node = @import("../../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const exprEmitter = @import("expr_emitter.zig");
const declEmitter = @import("decl_emitter.zig");

pub const JsBackend = struct {
    const WriteCtx = WriteContext(.{});

    backend: Backend,
    writeCtx: *WriteCtx,
    out: WriteCtx.Writer,

    pub fn new(alloc: *Allocator) !JsBackend {
        var ctx = try WriteCtx.new(alloc);
        return JsBackend{
            .backend = Backend{
                .callbacks = .{
                    .prolog = JsBackend.prolog,
                    .epilog = JsBackend.epilog,
                    .declaration = JsBackend.declaration,
                    .expression = JsBackend.expression,
                },
            },
            .writeCtx = ctx,
            .out = ctx.writer(),
        };
    }

    pub fn deinit(self: *JsBackend) void {
        self.writeCtx.deinit();
    }

    pub fn toString(self: JsBackend) ![]u8 {
        return try self.writeCtx.toString();
    }

    pub fn freeString(self: JsBackend, str: []u8) void {
        return self.writeCtx.freeString(str);
    }

    fn getSelf(be: *Backend) *JsBackend {
        return @fieldParentPtr(JsBackend, "backend", be);
    }

    fn prolog(be: *Backend) Backend.Error!void {
        const self = JsBackend.getSelf(be);
        try self.out.print("// Generated by glinka\n", .{});
    }

    fn epilog(be: *Backend) Backend.Error!void {
        const self = JsBackend.getSelf(be);
        try self.out.print("// End of glinka compilation", .{});
    }

    pub fn emitExpr(self: JsBackend, value: Node) Backend.Error!void {
        return try exprEmitter.emitExpr(self, value);
    }

    fn declaration(be: *Backend, nd: Node) Backend.Error!void {
        std.debug.assert(nd.getType() == NodeType.Decl);
        const self = JsBackend.getSelf(be);
        const decl = nd.data.Decl;
        try declEmitter.emitDecl(self, decl);
    }

    fn expression(be: *Backend, nd: Node) Backend.Error!void {
        const self = JsBackend.getSelf(be);
        try self.emitExpr(nd);
        try self.out.print(";\n", .{});
    }
};

test "JsBackend can emit prolog" {
    var backend = try JsBackend.new(std.testing.allocator);
    defer backend.deinit();
    try backend.backend.prolog();
    const str = try backend.toString();
    defer backend.freeString(str);
    try expectEqualStrings("// Generated by glinka\n", str);
}

test "JsBackend can emit epilog" {
    var backend = try JsBackend.new(std.testing.allocator);
    defer backend.deinit();
    try backend.backend.epilog();
    const str = try backend.toString();
    defer backend.freeString(str);
    try expectEqualStrings("// End of glinka compilation", str);
}
