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
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Scope = @import("scope.zig").Scope;
const TypeBook = @import("typebook.zig").TypeBook;
const Type = @import("../common/types/type.zig").Type;
const allocate = @import("../common/allocate.zig");

const builtinMap = std.ComptimeStringMap(
    fn (self: *TypeBook) Type.Ptr,
    .{
        .{ "number", TypeBook.getNumber },
        .{ "string", TypeBook.getString },
        .{ "boolean", TypeBook.getBoolean },
        .{ "void", TypeBook.getVoid },
        .{ "any", TypeBook.getAny },
    },
);

pub fn findType(scope: *Scope, typebook: *TypeBook, nd: Node) ?Type.Ptr {
    _ = scope;

    switch (nd.data) {
        .TypeName => |name| {
            if (builtinMap.get(name)) |func| {
                return func(typebook);
            } else {
                // TODO: Lookup in scope if not builtin
                return null;
            }
        },
        .ArrayType => |arr| {
            const subtype = findType(scope, typebook, arr);
            return if (subtype) |st|
                typebook.getArray(st)
            else
                null;
        },
        .UnionType => |un| {
            const alloc = scope.getAllocator();
            const tys = allocate.alloc(alloc, Type.Ptr, un.items.len);
            defer alloc.free(tys);

            for (un.items) |item, index| {
                if (findType(scope, typebook, item)) |ty|
                    tys[index] = ty
                else
                    return null;
            }

            return typebook.getUnion(tys);
        },
        // TODO: Process function type literals
        else => return null,
    }
}

const FindTypeTestCase = struct {
    inputNode: Node,
    check: fn (ty: ?Type.Ptr) anyerror!void,

    pub fn run(self: FindTypeTestCase) !void {
        const scope = Scope.new(std.testing.allocator, null);
        defer scope.deinit();

        var typebook = TypeBook.new(std.testing.allocator);
        defer typebook.deinit();

        defer std.testing.allocator.destroy(self.inputNode);

        const ty = findType(scope, typebook, self.inputNode);
        try self.check(ty);
    }
};

test "can lookup builtin types" {
    try (FindTypeTestCase{
        .inputNode = makeNode(
            std.testing.allocator,
            Cursor.new(11, 4),
            .TypeName,
            "number",
        ),
        .check = (struct {
            fn check(ty: ?Type.Ptr) anyerror!void {
                try expect(ty != null);
                try expectEqual(Type.Type.Number, ty.?.getType());
            }
        }).check,
    }).run();
}

test "can lookup array types" {
    const alloc = std.testing.allocator;
    const csr = Cursor.new(6, 7);

    const string = makeNode(alloc, csr, .TypeName, "string");
    defer alloc.destroy(string);

    try (FindTypeTestCase{
        .inputNode = makeNode(alloc, csr, .ArrayType, string),
        .check = (struct {
            fn check(ty: ?Type.Ptr) anyerror!void {
                try expectEqual(Type.Type.Array, ty.?.getType());
                try expectEqual(Type.Type.String, ty.?.Array.subtype.getType());
            }
        }).check,
    }).run();
}

test "can lookup union types" {
    const alloc = std.testing.allocator;
    const csr = Cursor.new(6, 7);

    const string = makeNode(alloc, csr, .TypeName, "string");
    const number = makeNode(alloc, csr, .TypeName, "number");
    defer alloc.destroy(string);
    defer alloc.destroy(number);

    var list = node.NodeList{};
    defer list.deinit(alloc);
    try list.append(alloc, string);
    try list.append(alloc, number);

    try (FindTypeTestCase{
        .inputNode = makeNode(alloc, csr, .UnionType, list),
        .check = (struct {
            fn check(ty: ?Type.Ptr) anyerror!void {
                try expectEqual(Type.Type.Union, ty.?.getType());

                const tys: []Type.Ptr = ty.?.Union.tys;
                try expectEqual(@intCast(usize, 2), tys.len);
                try expectEqual(Type.Type.Number, tys[0].getType());
                try expectEqual(Type.Type.String, tys[1].getType());
            }
        }).check,
    }).run();
}
