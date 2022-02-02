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

pub const Visibility = enum {
    Public,
    Protected,
    Private,

    pub fn toString(self: Visibility) []const u8 {
        return switch (self) {
            .Public => "public",
            .Protected => "protected",
            .Private => "private",
        };
    }
};

test "can convert visibility to string" {
    try std.testing.expectEqualStrings(
        "public",
        Visibility.Public.toString(),
    );
    try std.testing.expectEqualStrings(
        "protected",
        Visibility.Protected.toString(),
    );
    try std.testing.expectEqualStrings(
        "private",
        Visibility.Private.toString(),
    );
}
