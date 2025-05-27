const std = @import("std");

pub fn build(b: *std.Build) void {
    // options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main_mod = b.createModule(.{
        .root_source_file = b.path("./src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "Nes",
        .root_module = main_mod,
    });

    exe.linkSystemLibrary("X11");
    exe.linkSystemLibrary("Xext");
    exe.linkLibC();

    b.installArtifact(exe);

    const raylib = b.addStaticLibrary(.{
        .name = "raylib",
        .target = target,
        .optimize = optimize,
    });

    raylib.addCSourceFiles(.{ .files = &.{
        "lib/raylib/src/rcore.c",
        "lib/raylib/src/rshapes.c",
        "lib/raylib/src/rtextures.c",
        "lib/raylib/src/rtext.c",
        "lib/raylib/src/rmodels.c",
        "lib/raylib/src/utils.c",
        "lib/raylib/src/raudio.c",
    }, .flags = &.{"-fno-sanitize=undefined"} });

    raylib.linkLibC();
    raylib.addIncludePath(b.path("lib/raylib/src"));
    raylib.addIncludePath(b.path("lib/raylib/src/external/glfw/include/"));

    // create internal run step that depend on exe install
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // create public run step: `zig build run`
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
