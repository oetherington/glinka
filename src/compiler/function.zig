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
const Compiler = @import("compiler.zig").Compiler;
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const Type = @import("types/type.zig").Type;
const TypeError = @import("types/type_error.zig").TypeError;
const RedefinitionError = @import("redefinition_error.zig").RedefinitionError;
const GenericError = @import("generic_error.zig").GenericError;
const CompileError = @import("compile_error.zig").CompileError;
const CompilerTestCase = @import("compiler_test_case.zig").CompilerTestCase;
const allocate = @import("../common/allocate.zig");

fn checkName(cmp: *Compiler, csr: Cursor, func: node.Function) bool {
    if (func.name) |name| {
        if (cmp.scope.getLocal(name)) |_| {
            cmp.errors.append(CompileError.genericError(
                GenericError.new(csr, cmp.fmt(
                    "Symbol '{s}' is already defined",
                    .{name},
                )),
            )) catch allocate.reportAndExit();
            return false;
        }
    }

    return true;
}

fn addReturnTypeError(cmp: *Compiler, csr: Cursor, funcName: ?[]const u8) void {
    const message = if (funcName) |fName|
        cmp.fmt("Invalid return type for function '{s}'", .{fName})
    else
        "Invalid return type for anonymous function";

    cmp.errors.append(CompileError.genericError(
        GenericError.new(csr, message),
    )) catch allocate.reportAndExit();
}

fn getReturnType(cmp: *Compiler, csr: Cursor, func: node.Function) Type.Ptr {
    if (func.retTy) |ty| {
        if (cmp.findType(ty)) |retTy| {
            return retTy;
        } else {
            addReturnTypeError(cmp, csr, func.name);
            return cmp.typebook.getAny();
        }
    } else {
        return cmp.typebook.getVoid();
    }
}

fn addArgTypeError(
    cmp: *Compiler,
    csr: Cursor,
    argName: []const u8,
    funcName: ?[]const u8,
) void {
    const message = if (funcName) |fName|
        cmp.fmt(
            "Invalid type for argument '{s}' in function '{s}'",
            .{ argName, fName },
        )
    else
        cmp.fmt(
            "Invalid type for argument '{s}' in anonymous function",
            .{argName},
        );

    cmp.errors.append(CompileError.genericError(
        GenericError.new(csr, message),
    )) catch allocate.reportAndExit();
}

fn getArgType(
    cmp: *Compiler,
    csr: Cursor,
    funcName: ?[]const u8,
    arg: node.Function.Arg,
) Type.Ptr {
    if (arg.ty) |declared| {
        if (cmp.findType(declared)) |argTy| {
            return argTy;
        } else {
            addArgTypeError(cmp, csr, arg.name, funcName);
            return cmp.typebook.getAny();
        }
    } else {
        return cmp.implicitAny(csr, arg.name);
    }
}

pub fn processFunction(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == NodeType.Function);

    const func = nd.data.Function;

    std.debug.assert(!func.isArrow); // TODO: Implement arrow functions
    std.debug.assert(func.body.getType() == .Block);

    const nameIsValid = checkName(cmp, nd.csr, func);

    const retTy = getReturnType(cmp, nd.csr, func);

    cmp.pushScope();
    defer cmp.popScope();

    cmp.scope.ctx = .Function;

    const argTys = allocate.alloc(cmp.alloc, Type.Ptr, func.args.items.len);
    defer cmp.alloc.free(argTys);

    for (func.args.items) |arg, index| {
        argTys[index] = getArgType(cmp, nd.csr, func.name, arg);
        cmp.scope.put(arg.name, argTys[index], false, arg.csr);
    }

    cmp.scope.put("this", cmp.typebook.getObject(), true, nd.csr);

    const funcTy = cmp.typebook.getFunction(retTy, argTys);

    if (nameIsValid)
        if (func.name) |name|
            cmp.scope.parent.?.put(name, funcTy, true, nd.csr);

    cmp.processNode(func.body);

    // TODO: Check all code paths return a value of the correct type
}

test "can compile a function" {
    try (CompilerTestCase{
        .code = "function adder(a: number, b: number) : number { a + b; }",
    }).run();
}

test "untyped function arguments trigger implicit any" {
    try (CompilerTestCase{
        .code = "function aFunction(a) {}",
        .check = (struct {
            pub fn check(self: CompilerTestCase, cmp: Compiler) anyerror!void {
                try self.expectEqual(@intCast(usize, 1), cmp.errors.count());

                const err = cmp.getError(0);
                try self.expectEqual(
                    CompileError.Type.ImplicitAnyError,
                    err.getType(),
                );
                try self.expectEqualStrings("a", err.ImplicitAnyError.symbol);
            }
        }).check,
    }).run();
}

fn fnGenericErrorTestCase(
    comptime code: []const u8,
    comptime expectedMessage: []const u8,
) !void {
    try (CompilerTestCase{
        .code = code,
        .check = (struct {
            pub fn check(self: CompilerTestCase, cmp: Compiler) anyerror!void {
                try self.expectEqual(@intCast(usize, 1), cmp.errors.count());

                const err = cmp.getError(0);
                try self.expectEqual(
                    CompileError.Type.GenericError,
                    err.getType(),
                );
                try self.expectEqualStrings(
                    expectedMessage,
                    err.GenericError.msg,
                );
            }
        }).check,
    }).run();
}

test "invalid function argument types throw an error in named functions" {
    try fnGenericErrorTestCase(
        "function aFunction(a: AnInvalidType) {}",
        "Invalid type for argument 'a' in function 'aFunction'",
    );
}

test "invalid function argument types throw an error in anonymous functions" {
    try fnGenericErrorTestCase(
        "function(a: AnInvalidType) {}",
        "Invalid type for argument 'a' in anonymous function",
    );
}

test "invalid function return type throws an error in named functions" {
    try fnGenericErrorTestCase(
        "function aFunction() : AnInvalidType {}",
        "Invalid return type for function 'aFunction'",
    );
}

test "invalid function return type throws an error in anonymous functions" {
    try fnGenericErrorTestCase(
        "function() : AnInvalidType {}",
        "Invalid return type for anonymous function",
    );
}

test "function throws error if symbol is already defined" {
    try fnGenericErrorTestCase(
        "function someFunction() {} function someFunction() {}",
        "Symbol 'someFunction' is already defined",
    );
}
