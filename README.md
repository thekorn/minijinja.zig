# minijinja.zig

![ci workflow](https://github.com/thekorn/minijinja.zig/actions/workflows/ci.yaml/badge.svg)

zig bindings for the amazing [minijinja](https://github.com/mitsuhiko/minijinja) templating engine.
It's a thin wrapper around the C ABI of minijinja.

**NOTE**: this is a work in progress and mac only at the moment.

## Requirements

- zig >= 0.14
- rustup (for building minijinja-capi) or
- a nix environment (and then use `nix develop` to get a shell with all dependencies)

## Usage

Add this package to your zig project:

```bash
$ zig fetch --save git+https://github.com/thekorn/minijinja.zig#main
```

Add dependency and import to the `build.zig` file:

```zig
...
const minijinja = b.dependency("minijinja", .{
    .target = target,
    .optimize = optimize,
});
...
exe.root_module.addImport("minijinja", minijinja.module("minijinja"));
```

And then, just use it in the code:

```zig
const std = @import("std");

const minijinja = @import("minijinja");
const Environment = minijinja.Environment;
const Context = minijinja.Context;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const templ =
        \\<ul>
        \\{%- for user in users %}
        \\  <li>{{ user.name }}</li>
        \\{%- endfor %}
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

    const t = try env.render_template_struct(allocator, "list", .{ .users = users });
    defer allocator.free(t);

    std.debug.print("{s}\n", .{t});
}
```

Which results in

```
<ul>
  <li>Hans</li>
  <li>Wurst</li>
</ul>
```

## Tests

Using `nix` tests can be run like

```bash
$ nix develop -c zig build test --summary all
```
