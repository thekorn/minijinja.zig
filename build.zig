const std = @import("std");
const Build = std.Build;
const Step = Build.Step;
const Module = Build.Module;

const BuildOptions = struct {
    opt: std.builtin.OptimizeMode,
    target: Build.ResolvedTarget,

    fn init(b: *Build) BuildOptions {
        return .{
            .opt = b.standardOptimizeOption(.{}),
            .target = b.standardTargetOptions(.{}),
        };
    }
};

fn runCargo(b: *Build, options: BuildOptions, crate_root: []const u8, output_file: []const u8, target: ?[]const u8, extra_args: []const []const u8) Build.LazyPath {
    const tool_run = b.addSystemCommand(&.{"cargo"});
    const crate_root_lazy = b.path(crate_root);
    tool_run.setCwd(crate_root_lazy);
    tool_run.addArg("build");
    if (target) |t| {
        tool_run.addArgs(&.{ "--target", t });
    }
    tool_run.addArgs(extra_args);

    var opt_path: []const u8 = undefined;
    switch (options.opt) {
        .ReleaseSafe,
        .ReleaseFast,
        .ReleaseSmall,
        => {
            tool_run.addArg("--release");
            opt_path = "release";
        },
        .Debug => {
            opt_path = "debug";
        },
    }

    const generated = b.allocator.create(std.Build.GeneratedFile) catch unreachable;
    var path = b.build_root.join(b.allocator, &.{ crate_root, "target", opt_path, output_file }) catch unreachable;
    if (target) |t| {
        path = b.build_root.join(b.allocator, &.{ crate_root, "target", t, opt_path, output_file }) catch unreachable;
    }

    generated.* = .{
        .step = &tool_run.step,
        .path = path,
    };

    const lib_path = std.Build.LazyPath{ .generated = .{
        .file = generated,
    } };

    return lib_path;
}

const Libs = struct {
    minijinja: Build.LazyPath,
    minijinja_include: Build.LazyPath,
    link_mode: std.builtin.LinkMode,

    fn init(b: *Build, options: BuildOptions) Libs {
        const link_mode: std.builtin.LinkMode = switch (options.opt) {
            // dynamic is faster, but harder to ship
            .Debug => .dynamic,
            else => .static,
        };
        return .{
            .minijinja = runCargo(
                b,
                options,
                "lib/minijinja/",
                "libminijinja_cabi.dylib",
                null,
                &.{ "-p", "minijinja-cabi" },
            ),
            .minijinja_include = b.path("lib/minijinja/minijinja-cabi/include/"),
            .link_mode = link_mode,
        };
    }

    fn link(self: *Libs, exe: *Step.Compile, name: []const u8) void {
        exe.root_module.linkSystemLibrary(name, .{
            .preferred_link_mode = self.link_mode,
        });
    }

    fn linkModule(self: *Libs, mod: *Module, name: []const u8) void {
        mod.linkSystemLibrary(name, .{
            .preferred_link_mode = self.link_mode,
        });
    }

    fn linkAll(self: *Libs, exe: *Step.Compile) void {
        exe.addLibraryPath(self.minijinja.dirname());
        exe.addIncludePath(self.minijinja_include);
        self.link(exe, "minijinja_cabi");
    }

    fn linkAllModule(self: *Libs, mod: *Module) void {
        mod.addLibraryPath(self.minijinja.dirname());
        mod.addIncludePath(self.minijinja_include);
        self.linkModule(mod, "minijinja_cabi");
    }
};

const Builder = struct {
    b: *Build,
    libs: Libs,
    options: BuildOptions,

    fn init(b: *Build) Builder {
        const options = BuildOptions.init(b);
        return .{
            .b = b,
            .libs = Libs.init(b, options),
            .options = options,
        };
    }
};

const MinjinjaBuilder = struct {
    minijinja: *Module,
    minijinja_unit_tests: *Step.Compile,

    fn init(b: *Build, builder: *Builder) MinjinjaBuilder {
        const minijinja = b.addModule("minijinja", .{
            .root_source_file = b.path("src/main.zig"),
            .target = builder.options.target,
            .optimize = builder.options.opt,
            .link_libc = true,
        });
        builder.libs.linkAllModule(minijinja);
        const minijinja_unit_tests = b.addTest(.{
            .root_source_file = minijinja.root_source_file orelse unreachable,
            .target = builder.options.target,
            .test_runner = b.path("test_runner.zig"),
            .optimize = builder.options.opt,
            .link_libc = true,
        });
        builder.libs.linkAll(minijinja_unit_tests);
        return .{
            .minijinja = minijinja,
            .minijinja_unit_tests = minijinja_unit_tests,
        };
    }

    fn addImport(self: *MinjinjaBuilder, mod: *Build.Module) void {
        //const m = @constCast(self.minijinja);
        mod.addImport("minijinja", self.minijinja);
    }
};

pub fn build(b: *std.Build) void {
    var builder = Builder.init(b);

    const mb = MinjinjaBuilder.init(b, &builder);
    //const minijinja = mb.minijinja;
    const minijinja_unit_tests = mb.minijinja_unit_tests;

    const run_minijinja_unit_tests = b.addRunArtifact(minijinja_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_minijinja_unit_tests.step);
}
