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
const node = @import("node.zig");
const Node = node.Node;

pub const Backend = struct {
    pub const Error = anyerror;

    pub const Callback = fn (be: *Backend) Error!void;
    pub const NodeCallback = fn (be: *Backend, nd: Node) Error!void;

    pub const Callbacks = struct {
        prolog: Callback,
        epilog: Callback,
        declaration: NodeCallback,
        expression: NodeCallback,
    };

    callbacks: Callbacks,

    pub fn prolog(self: *Backend) Error!void {
        try self.callbacks.prolog(self);
    }

    pub fn epilog(self: *Backend) Error!void {
        try self.callbacks.epilog(self);
    }

    pub fn declaration(self: *Backend, nd: Node) Error!void {
        try self.callbacks.declaration(self, nd);
    }

    pub fn expression(self: *Backend, nd: Node) Error!void {
        try self.callbacks.expression(self, nd);
    }
};
