const std = @import("std");
const c = @import("c.zig");

const mj_error = @import("error.zig");
const Context = @import("Context.zig");
const convert_to_context = Context.convert_to_context;

const Environment = @This();

mj_env: ?*c.struct_mj_env,

pub fn init() !Environment {
    const env = c.mj_env_new();
    return .{
        .mj_env = env,
    };
}

pub fn deinit(self: *Environment) void {
    c.mj_env_free(self.mj_env);
}

pub fn set_debug(self: *Environment, enable: bool) void {
    c.mj_env_set_debug(self.mj_env, enable);
}

pub fn add_template(self: *Environment, name: [*c]const u8, source: [*c]const u8) mj_error.MinijinjaError!void {
    const ok = c.mj_env_add_template(self.mj_env, name, source);
    if (!ok) {
        return mj_error.get_error_from_int(c.mj_err_get_kind());
    }
}

pub fn render_template(self: *Environment, alloc: std.mem.Allocator, name: [*c]const u8, ctx: Context) ![]const u8 {
    const result = c.mj_env_render_template(self.mj_env, name, ctx.data);
    defer c.mj_str_free(result);
    if (result == null) {
        return mj_error.get_error_from_int(c.mj_err_get_kind());
    }

    // why cant I use dupeZ() here?
    // https://mtlynch.io/notes/zig-strings-call-c-code/#improving-the-wrapper-with-zig-managed-buffers
    // (it panics the tests)
    const zig_string: []const u8 = std.mem.span(result);

    var list = std.ArrayList(u8).init(alloc);
    defer list.deinit();

    try list.appendSlice(zig_string);

    return try list.toOwnedSlice();
}

pub fn render_template_struct(self: *Environment, alloc: std.mem.Allocator, name: [*c]const u8, ctx_struct: anytype) ![]const u8 {
    const ctx = try convert_to_context(ctx_struct);
    return self.render_template(alloc, name, ctx);
}

test "render simple template struct" {
    var env = try Environment.init();
    defer env.deinit();

    env.set_debug(true);

    try env.add_template("hello", "Hello {{ name }}!");

    const t = try env.render_template_struct(std.testing.allocator, "hello", .{ .name = "Hans" });
    defer std.testing.allocator.free(t);

    try std.testing.expectEqualStrings("Hello Hans!", t);
}

test "render multiline struct template using template" {
    const templ =
        \\<ul>
        \\{%- for user in users %}
        \\  <li>{{ user.name }}</li>
        \\{%- endfor %}
        \\</ul>
    ;

    const expected =
        \\<ul>
        \\  <li>Hans</li>
        \\  <li>Wurst</li>
        \\</ul>
    ;

    var env = try Environment.init();
    defer env.deinit();

    env.set_debug(true);

    try env.add_template("list", templ);

    const User = struct {
        name: []const u8,
    };

    const users = [_]User{
        .{ .name = "Hans" },
        .{ .name = "Wurst" },
    };

    const t = try env.render_template_struct(std.testing.allocator, "list", .{ .users = users });
    defer std.testing.allocator.free(t);

    try std.testing.expectEqualStrings(expected, t);
}

test "render list of floats" {
    const templ = "[{%- for num in nums %} {{ num }} {%- endfor %}]";

    const expected = "[ 2.0 4.0]";

    var env = try Environment.init();
    defer env.deinit();

    try env.add_template("list", templ);

    const nums = [_]f64{
        2.0, 4.0,
    };

    const t = try env.render_template_struct(std.testing.allocator, "list", .{ .nums = nums });
    defer std.testing.allocator.free(t);

    try std.testing.expectEqualStrings(expected, t);
}

test "render list of ints" {
    const templ = "[{%- for num in nums %} {{ num }} {%- endfor %}]";

    const expected = "[ 1 5]";

    var env = try Environment.init();
    defer env.deinit();

    try env.add_template("list", templ);

    const nums = [_]i64{ 1, 5 };

    const t = try env.render_template_struct(std.testing.allocator, "list", .{ .nums = nums });
    defer std.testing.allocator.free(t);

    try std.testing.expectEqualStrings(expected, t);
}

test "render list of strings" {
    const templ = "[{%- for str in strings %} {{ str }} {%- endfor %}]";

    const expected = "[ hello world]";

    var env = try Environment.init();
    defer env.deinit();

    try env.add_template("list", templ);

    const strings = [_][]const u8{ "hello", "world" };

    const t = try env.render_template_struct(std.testing.allocator, "list", .{ .strings = strings });
    defer std.testing.allocator.free(t);

    try std.testing.expectEqualStrings(expected, t);
}

test "render list of structs" {
    const templ = "[{%- for user in users %} {{ user.name }} {{ user.location.city }} {%- endfor %}]";

    const expected = "[ Hans Berlin Wurst Munich]";

    var env = try Environment.init();
    defer env.deinit();

    try env.add_template("list", templ);

    const User = struct { name: []const u8, location: struct {
        city: []const u8,
    } };

    const users = [_]User{
        .{ .name = "Hans", .location = .{ .city = "Berlin" } },
        .{ .name = "Wurst", .location = .{ .city = "Munich" } },
    };

    const t = try env.render_template_struct(std.testing.allocator, "list", .{ .users = users });
    defer std.testing.allocator.free(t);

    try std.testing.expectEqualStrings(expected, t);
}

test "render list of structs including optional field" {
    const templ = "[{%- for user in users %} {{ user.name }} {{ user.location.city |default('unknown') }} {%- endfor %}]";

    const expected = "[ Hans Berlin Wurst unknown]";

    var env = try Environment.init();
    defer env.deinit();

    try env.add_template("list", templ);

    const User = struct { name: []const u8, location: ?struct {
        city: []const u8,
    } };

    const users = [_]User{
        .{ .name = "Hans", .location = .{ .city = "Berlin" } },
        .{ .name = "Wurst", .location = null },
    };

    const t = try env.render_template_struct(std.testing.allocator, "list", .{ .users = users });
    defer std.testing.allocator.free(t);

    try std.testing.expectEqualStrings(expected, t);
}

test "render list optional ints" {
    const templ = "[{%- for num in nums %} {{ num }} {%- endfor %}]";

    const expected = "[ 1 none 3 4]";

    var env = try Environment.init();
    defer env.deinit();

    try env.add_template("list", templ);

    const nums = [_]?i64{
        1, null, 3, 4,
    };

    const t = try env.render_template_struct(std.testing.allocator, "list", .{ .nums = nums });
    defer std.testing.allocator.free(t);

    try std.testing.expectEqualStrings(expected, t);
}

test "render list optional ints with skipping null values" {
    const templ = "[{%- for num in nums %} {{ num if num is not none }} {%- endfor %}]";

    const expected = "[ 1  3 4]";

    var env = try Environment.init();
    defer env.deinit();

    try env.add_template("list", templ);

    const nums = [_]?i64{
        1, null, 3, 4,
    };

    const t = try env.render_template_struct(std.testing.allocator, "list", .{ .nums = nums });
    defer std.testing.allocator.free(t);

    try std.testing.expectEqualStrings(expected, t);
}
