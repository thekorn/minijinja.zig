const std = @import("std");
const c = @import("c.zig");
const utils = @import("utils.zig");
const convertType = utils.convertType;
const print_debug = utils.print_debug;

const List = @This();

data: c.struct_mj_value,

pub fn init() List {
    return .{
        .data = c.mj_value_new_list(),
    };
}

pub fn append(self: *List, value: c.struct_mj_value) !void {
    const ok = c.mj_value_append(&self.data, value);
    if (!ok) {
        std.debug.panic("Cannot append value of type {s}", .{@typeName(@TypeOf(value))});
        return error.FailedToSet;
    }
}

test "debug List" {
    var seq = List.init();
    try seq.append(try convertType(32));
    try seq.append(try convertType("First"));
    try seq.append(try convertType("Second"));
    print_debug(seq.data);
}
