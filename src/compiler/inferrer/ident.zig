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

const Cursor = @import("../../common/cursor.zig").Cursor;
const Compiler = @import("../compiler.zig").Compiler;
const Scope = @import("../scope.zig").Scope;
const TypeBook = @import("../typebook.zig").TypeBook;
const node = @import("../../common/node.zig");
const InferResult = @import("infer_result.zig").InferResult;
const InferTestCase = @import("infer_test_case.zig").InferTestCase;

pub fn inferIdentType(
    cmp: *Compiler,
    nd: node.Node,
    ident: []const u8,
) InferResult {
    nd.ty = if (cmp.scope.get(ident)) |sym|
        sym.ty
    else
        cmp.typebook.getUndefined();

    return InferResult.success(nd.ty.?);
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
