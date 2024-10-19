const std = @import("std");

const utils = @import("utils.zig");
const convertType = utils.convertType;
pub const print_debug = utils.print_debug;
pub const print_error = utils.print_error;
pub const get_error_detail = utils.get_error_detail;
pub const Environment = @import("Environment.zig");
pub const Context = @import("Context.zig");
pub const List = @import("List.zig");

test "render simple template" {
    var env = try Environment.init();
    defer env.deinit();

    env.set_debug(true);

    try env.add_template("hello", "Hello {{ name }}!");

    var ctx = Context.init();
    try ctx.set("name", try convertType("Hans"));

    const t = try env.render_template(std.testing.allocator, "hello", ctx);
    defer std.testing.allocator.free(t);

    try std.testing.expectEqualStrings("Hello Hans!", t);
}

test "render multiline template" {
    const templ =
        \\Hello {{ name }}!
        \\{%- for item in seq %}
        \\  - {{ item }}
        \\{%- endfor %}
        \\seq: {{ seq }}
    ;

    const expected =
        \\Hello Hans!
        \\  - 32
        \\  - First
        \\  - Second
        \\seq: [32, "First", "Second"]
    ;

    var env = try Environment.init();
    defer env.deinit();

    env.set_debug(true);

    try env.add_template("hello", templ);

    var ctx = Context.init();

    var seq = List.init();
    try seq.append(try convertType(32));
    try seq.append(try convertType("First"));
    try seq.append(try convertType("Second"));

    try ctx.set("seq", seq.data);
    try ctx.set("name", try convertType("Hans"));

    const t = try env.render_template(std.testing.allocator, "hello", ctx);
    defer std.testing.allocator.free(t);

    try std.testing.expectEqualStrings(expected, t);
}

test "render multiline struct template" {
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

    var ctx = Context.init();

    var users = List.init();

    const user1 = try convertType(.{ .name = "Hans" });
    const user2 = try convertType(.{ .name = "Wurst" });

    try users.append(user1);
    try users.append(user2);

    try ctx.set("users", users.data);

    const t = try env.render_template(std.testing.allocator, "list", ctx);
    defer std.testing.allocator.free(t);

    try std.testing.expectEqualStrings(expected, t);
}

test {
    _ = Environment;
    _ = Context;
}
