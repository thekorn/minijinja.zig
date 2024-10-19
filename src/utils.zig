const std = @import("std");
const c = @import("c.zig");

pub fn get_error_detail() ![*c]const u8 {
    return c.mj_err_get_detail() orelse error.NoErrorDetails;
}

pub fn print_error() !void {
    const result = c.mj_err_print();
    if (!result) return error.NoError;
}

pub fn print_debug(value: c.struct_mj_value) void {
    c.mj_value_dbg(value);
}

// This is based on the `std.fmt.formatType` function
// https://github.com/ziglang/zig/blob/master/lib/std/fmt.zig#L486
pub fn convertType(
    value: anytype,
) !c.struct_mj_value {
    const T = @TypeOf(value);

    switch (@typeInfo(T)) {
        .comptime_int, .int => {
            return c.mj_value_new_i64(value);
        },
        .comptime_float, .float => {
            return c.mj_value_new_f64(value);
        },
        .optional => {
            if (value) |payload| {
                std.log.debug("Value is an 'optional with value'", .{});
                return convertType(payload);
            } else {
                std.log.debug("Value is an 'optional which is null'", .{});
                return convertType(null);
            }
        },
        .@"struct" => |info| {
            if (info.is_tuple) {
                std.log.debug("Value is a 'tuple'", .{});
                inline for (info.fields) |f| {
                    return convertType(@field(value, f.name));
                }
            }
            std.log.debug("Value is a 'struct'", .{});
            var obj = c.mj_value_new_object();
            inline for (info.fields) |f| {
                const v = try convertType(@field(value, f.name));
                const ok = c.mj_value_set_string_key(&obj, f.name, v);
                if (!ok) {
                    std.debug.panic("Cannot set key='{s}' to value of type {s}", .{ f.name, @typeName(T) });
                    return error.FailedToSet;
                }
            }
            return obj;
        },
        .pointer => |ptr_info| switch (ptr_info.size) {
            .One => switch (@typeInfo(ptr_info.child)) {
                .array, .@"enum", .@"union", .@"struct" => {
                    std.log.debug("Value is a '.Pointer.One.Nested'", .{});
                    return convertType(value.*);
                },
                else => error.NotImplemented,
            },
            .Many, .C => {
                return error.NotImplemented;
            },
            .Slice => {
                if (ptr_info.child == u8) {
                    std.log.debug("Value is a 'string slice'", .{});
                    return c.mj_value_new_string(value.ptr);
                }
                std.log.debug("Value is a 'slice of'", .{});
                var lst = c.mj_value_new_list();
                for (value) |elem| {
                    const v = try convertType(elem);
                    const ok = c.mj_value_append(&lst, v);
                    if (!ok) {
                        std.debug.panic("Cannot append value of type {s}", .{@typeName(@TypeOf(elem))});
                        return error.FailedToAppend;
                    }
                }
                return lst;
            },
        },
        .array => |info| {
            if (info.child == u8) {
                std.log.debug("Value is a 'string array'", .{});
                const c_string = value[0..];
                return c.mj_value_new_string(c_string.ptr);
            }
            std.log.debug("Value is a 'array of'", .{});
            var lst = c.mj_value_new_list();
            for (value) |elem| {
                const v = try convertType(elem); //, max_depth - 1);
                const ok = c.mj_value_append(&lst, v);
                if (!ok) {
                    std.debug.panic("Cannot append value of type {s}", .{@typeName(@TypeOf(elem))});
                    return error.FailedToAppend;
                }
            }
            return lst;
        },
        .null => {
            return c.mj_value_new_none();
        },
        else => @compileError("unable to convert type '" ++ @typeName(T) ++ "'"),
    }
}
