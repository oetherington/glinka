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
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectError = std.testing.expectError;
const Cursor = @import("../cursor.zig").Cursor;
const Token = @import("../token.zig").Token;
const putInd = @import("indenter.zig").putInd;
const DumpTestCase = @import("dump_test_case.zig").DumpTestCase;
const nodeImp = @import("../node.zig");
const Node = nodeImp.Node;
const makeNode = nodeImp.makeNode;

pub const Decl = struct {
    pub const Scoping = enum {
        Var,
        Let,
        Const,

        pub fn fromTokenType(tkn: Token.Type) !Scoping {
            return switch (tkn) {
                .Var => .Var,
                .Let => .Let,
                .Const => .Const,
                else => error.InvalidScoping,
            };
        }

        pub fn toString(self: Scoping) []const u8 {
            return switch (self) {
                .Var => "var",
                .Let => "let",
                .Const => "const",
            };
        }
    };

    scoping: Scoping,
    name: []const u8,
    ty: ?Node,
    value: ?Node,

    pub fn new(
        scoping: Scoping,
        name: []const u8,
        ty: ?Node,
        value: ?Node,
    ) Decl {
        return Decl{
            .scoping = scoping,
            .name = name,
            .ty = ty,
            .value = value,
        };
    }

    pub fn dump(
        self: Decl,
        writer: anytype,
        indent: usize,
    ) !void {
        try putInd(writer, indent, "{s} Decl \"{s}\"\n", .{
            @tagName(self.scoping),
            self.name,
        });

        if (self.ty) |ty|
            try ty.dumpIndented(writer, indent + 2);

        if (self.value) |value|
            try value.dumpIndented(writer, indent + 2);
    }
};

test "can create Decl.Scoping from Token.Type" {
    try expectEqual(Decl.Scoping.Var, try Decl.Scoping.fromTokenType(.Var));
    try expectEqual(Decl.Scoping.Let, try Decl.Scoping.fromTokenType(.Let));
    try expectEqual(Decl.Scoping.Const, try Decl.Scoping.fromTokenType(.Const));
    try expectError(error.InvalidScoping, Decl.Scoping.fromTokenType(.Dot));
}

test "can convert Decl.Scoping to string" {
    try expectEqualStrings("var", Decl.Scoping.Var.toString());
    try expectEqualStrings("let", Decl.Scoping.Let.toString());
    try expectEqualStrings("const", Decl.Scoping.Const.toString());
}

test "can dump a Decl" {
    const nodes = [_]Node{
        makeNode(std.testing.allocator, Cursor.new(1, 1), .TypeName, "number"),
        makeNode(std.testing.allocator, Cursor.new(2, 1), .Int, "1"),
    };

    defer for (nodes) |node|
        std.testing.allocator.destroy(node);

    try (DumpTestCase(Decl, .Decl){
        .value = Decl.new(.Const, "aDeclaration", nodes[0], nodes[1]),
        .expected = 
        \\Const Decl "aDeclaration"
        \\  TypeName Node (1:1)
        \\    TypeName: "number"
        \\  Int Node (2:1)
        \\    Int: "1"
        \\
        ,
    }).run();
}
