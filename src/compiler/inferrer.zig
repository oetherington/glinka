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
const expectEqual = std.testing.expectEqual;
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("../frontend/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const makeNode = node.makeNode;
const Scope = @import("scope.zig").Scope;
const Type = @import("types/type.zig").Type;

pub fn inferExprType(scope: *Scope, nd: Node) Type {
    return switch (nd.data) {
        .Int => Type.newNumber(),
        .String, .Template => Type.newString(),
        .True, .False => Type.newBoolean(),
        .Null => Type.newNull(),
        .Undefined => Type.newUndefined(),
        .Ident => |ident| {
            const symbol = scope.get(ident);
            return if (symbol) |sym| sym.ty else Type.newUndefined();
        },
        else => Type.newUnknown(),
    };
}

fn inferTestCase(
    comptime nodeType: NodeType,
    nodeData: anytype,
    expectedType: Type.Type,
) !void {
    const scope = try Scope.new(std.testing.allocator, null);
    defer scope.deinit();

    const nd = try makeNode(
        std.testing.allocator,
        Cursor.new(6, 9),
        nodeType,
        nodeData,
    );
    defer std.testing.allocator.destroy(nd);

    const ty = inferExprType(scope, nd);
    try expectEqual(expectedType, ty.getType());
}

test "can inter type of int literal" {
    try inferTestCase(.Int, "1234", .Number);
}

test "can inter type of string literals" {
    try inferTestCase(.String, "1234", .String);
    try inferTestCase(.Template, "1234", .String);
}

test "can inter type of boolean" {
    try inferTestCase(.True, {}, .Boolean);
    try inferTestCase(.False, {}, .Boolean);
}

test "can inter type of 'null'" {
    try inferTestCase(.Null, {}, .Null);
}

test "can inter type of 'undefined'" {
    try inferTestCase(.Undefined, {}, .Undefined);
}

test "can inter type of an identifier" {
    // TODO
}

const builtinMap = std.ComptimeStringMap(Type, .{
    .{ "number", Type.newNumber() },
    .{ "string", Type.newString() },
    .{ "boolean", Type.newBoolean() },
    .{ "void", Type.newVoid() },
});

pub fn findType(scope: *Scope, nd: Node) !Type {
    _ = scope;

    switch (nd.data) {
        .TypeName => |name| {
            // TODO: Lookup in scope if not builtin
            return builtinMap.get(name) orelse error.InvalidType;
        },
        else => return error.InvalidType,
    }
}

test "can lookup builtin types" {
    const scope = try Scope.new(std.testing.allocator, null);
    defer scope.deinit();

    const nd = try makeNode(
        std.testing.allocator,
        Cursor.new(11, 4),
        .TypeName,
        "number",
    );
    defer std.testing.allocator.destroy(nd);

    const ty = try findType(scope, nd);
    try expectEqual(Type.Type.Number, ty.getType());
}
