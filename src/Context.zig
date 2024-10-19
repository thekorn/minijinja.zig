const std = @import("std");
const c = @import("c.zig");
const utils = @import("utils.zig");
const convertType = utils.convertType;
const print_debug = utils.print_debug;

const Context = @This();

data: c.struct_mj_value,

pub fn init() Context {
    return .{
        .data = c.mj_value_new_object(),
    };
}

pub fn set(self: *Context, key: [*c]const u8, value: c.struct_mj_value) !void {
    const ok = c.mj_value_set_string_key(&self.data, key, value);
    if (!ok) {
        std.debug.panic("Cannot set key='{s}' to value of type {s}", .{ key, @typeName(@TypeOf(value)) });
        return error.FailedToSet;
    }
}

pub fn convert_to_context(value: anytype) !Context {
    const CtxType = @TypeOf(value);
    const ctx_type_info = @typeInfo(CtxType);
    if (ctx_type_info != .@"struct") {
        @compileError("expected struct argument, found " ++ @typeName(CtxType));
    }

    const fields_info = ctx_type_info.@"struct".fields;
    var ctx = init();
    inline for (fields_info) |field| {
        const v = @field(value, field.name);
        try ctx.set(field.name, try convertType(v));
    }
    return ctx;
}

test "debug context" {
    const User = struct { name: []const u8, location: ?struct {
        city: []const u8,
    } };

    const users = [_]User{
        .{ .name = "Hans", .location = .{ .city = "Berlin" } },
        .{ .name = "Wurst", .location = null },
    };

    const ctx = try convert_to_context(.{ .users = users });
    print_debug(ctx.data);
}
