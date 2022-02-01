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
const Cursor = @import("../../common/cursor.zig").Cursor;
const Scope = @import("../scope.zig").Scope;
const TypeBook = @import("../typebook.zig").TypeBook;
const node = @import("../../common/node.zig");
const Type = @import("../../common/types/type.zig").Type;
const InferResult = @import("infer_result.zig").InferResult;
const InferTestCase = @import("infer_test_case.zig").InferTestCase;

pub fn inferPrimaryExprType(nd: node.Node, ty: Type.Ptr) InferResult {
    nd.ty = ty;
    return InferResult.success(ty);
}

test "can infer type of int literal" {
    try (InferTestCase{
        .expectedTy = .Number,
    }).run(.Int, "1234");
}

test "can infer type of float literal" {
    try (InferTestCase{
        .expectedTy = .Number,
    }).run(.Float, "1.234");
}

test "can infer type of string literals" {
    try (InferTestCase{
        .expectedTy = .String,
    }).run(.String, "'a string'");
}

test "can infer type of template literals" {
    try (InferTestCase{
        .expectedTy = .String,
    }).run(.Template, "`a template`");
}

test "can infer type of booleans" {
    try (InferTestCase{
        .expectedTy = .Boolean,
    }).run(.True, {});

    try (InferTestCase{
        .expectedTy = .Boolean,
    }).run(.False, {});
}

test "can infer type of 'null'" {
    try (InferTestCase{
        .expectedTy = .Null,
    }).run(.Null, {});
}

test "can infer type of 'undefined'" {
    try (InferTestCase{
        .expectedTy = .Undefined,
    }).run(.Undefined, {});
}

test "can infer type of an identifier" {
    try (InferTestCase{
        .expectedTy = .String,
        .setup = (struct {
            fn setup(
                scope: *Scope,
                typebook: *TypeBook,
            ) anyerror!void {
                scope.put(
                    "aVariable",
                    typebook.getString(),
                    false,
                    Cursor.new(0, 0),
                );
            }
        }).setup,
    }).run(.Ident, "aVariable");
}
