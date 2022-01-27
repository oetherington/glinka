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
const Compiler = @import("compiler.zig").Compiler;
const Cursor = @import("../common/cursor.zig").Cursor;
const node = @import("../common/node.zig");
const Node = node.Node;
const NodeType = node.NodeType;
const Type = @import("../common/types/type.zig").Type;
const TypeError = @import("errors/type_error.zig").TypeError;
const ReturnError = @import("errors/return_error.zig").ReturnError;
const GenericError = @import("errors/generic_error.zig").GenericError;
const CompileError = @import("errors/compile_error.zig").CompileError;
const CompilerTestCase = @import("compiler_test_case.zig").CompilerTestCase;
const WriteContext = @import("../common/writer.zig").WriteContext;
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

fn checkReturnExpr(
    cmp: *Compiler,
    csr: Cursor,
    expectedTy: Type.Ptr,
    actualTy: ?Type.Ptr,
) void {
    if (actualTy) |ty| {
        if (!ty.isAssignableTo(expectedTy)) {
            cmp.errors.append(CompileError.returnError(
                ReturnError.new(csr, expectedTy, ty),
            )) catch allocate.reportAndExit();
        }
    } else if (expectedTy.getType() != .Void) {
        cmp.errors.append(CompileError.returnError(
            ReturnError.new(csr, expectedTy, null),
        )) catch allocate.reportAndExit();
    }
}

fn traceReturns(cmp: *Compiler, nd: Node, retTy: Type.Ptr) void {
    // TODO: Check all code paths return a suitable value

    std.debug.assert(nd.getType() == .Block);

    if (retTy.getType() == .Any)
        return;

    for (nd.data.Block.items) |item| {
        switch (item.data) {
            .Return => |expr| checkReturnExpr(
                cmp,
                item.csr,
                retTy,
                if (expr) |exp| exp.ty else null,
            ),
            else => continue,
        }
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

    const hasFakeThis = func.args.items.len > 0 and std.mem.eql(
        u8,
        func.args.items[0].name,
        "this",
    );

    cmp.scope.put(
        "this",
        if (hasFakeThis)
            getArgType(cmp, nd.csr, func.name, func.args.items[0])
        else
            cmp.typebook.getAny(),
        true,
        nd.csr,
    );

    const argOffset: usize = if (hasFakeThis) 1 else 0;
    const argCount = func.args.items.len - argOffset;

    const argTys = allocate.alloc(cmp.alloc, Type.Ptr, argCount);
    defer cmp.alloc.free(argTys);

    for (func.args.items[argOffset..]) |arg, index| {
        argTys[index] = getArgType(cmp, nd.csr, func.name, arg);
        cmp.scope.put(arg.name, argTys[index], false, arg.csr);
    }

    // TODO: Check for construct signature?
    const funcTy = cmp.typebook.getFunction(retTy, argTys, false);

    if (nameIsValid)
        if (func.name) |name|
            cmp.scope.parent.?.put(name, funcTy, true, nd.csr);

    cmp.processNode(func.body);

    traceReturns(cmp, func.body, funcTy.Function.ret);
}

test "can compile a function" {
    try (CompilerTestCase{
        .code = "function adder(a: number, b: number) : void { a + b; }",
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

test "functions can have a fake 'this' parameter" {
    try (CompilerTestCase{
        .code = "function aFunction(this: number, param: string) {}",
        .check = (struct {
            pub fn check(self: CompilerTestCase, cmp: Compiler) anyerror!void {
                try self.checkNoErrors(cmp);

                const f = cmp.scope.get("aFunction");
                try self.expect(f != null);

                const ty = f.?.ty;
                try self.expectEqual(Type.Type.Function, ty.getType());
                try self.expectEqual(Type.Type.Void, ty.Function.ret.getType());

                const args = ty.Function.args;
                try self.expectEqual(@intCast(usize, 1), args.len);
                try self.expectEqual(Type.Type.String, args[0].getType());
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

pub fn processReturn(cmp: *Compiler, nd: Node) void {
    std.debug.assert(nd.getType() == NodeType.Return);

    if (nd.data.Return) |expr|
        _ = cmp.inferExprType(expr);
}

test "can compile a return statement" {
    try (CompilerTestCase{
        .code = "function id(a: number) : number { return a; }",
    }).run();
}

fn returnErrorTestCase(
    comptime code: []const u8,
    comptime expectedErr: []const u8,
) !void {
    try (CompilerTestCase{
        .code = code,
        .check = (struct {
            pub fn check(self: CompilerTestCase, cmp: Compiler) anyerror!void {
                try self.expectEqual(@intCast(usize, 1), cmp.errors.count());

                const err = cmp.getError(0);
                try self.expectEqual(
                    CompileError.Type.ReturnError,
                    err.getType(),
                );

                var ctx = try WriteContext(.{}).new(std.testing.allocator);
                defer ctx.deinit();
                var writer = ctx.writer();

                try cmp.errors.report(writer);

                var str = try ctx.toString();
                defer ctx.freeString(str);

                try self.expectEqualStrings(expectedErr, str);
            }
        }).check,
    }).run();
}

test "return statement expressions must have the correct type" {
    try returnErrorTestCase(
        "function f() : number { return 'not a number'; }",
        "Error: 1:25: Cannot return a value of type string from a function returning number\n",
    );
}

test "void functions must not return a value" {
    try returnErrorTestCase(
        "function f() : void { return 'not a number'; }",
        "Error: 1:23: Cannot return a value from a void function\n",
    );
}

test "non-void functions cannot return without a value" {
    try returnErrorTestCase(
        "function f() : string { return; }",
        "Error: 1:25: Non-void function must return value of type string\n",
    );
}
