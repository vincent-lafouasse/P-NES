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

    main_mod.addCSourceFiles(.{
        .root = b.path("./lib/minilibx-linux/"),
        .files = &[_][]const u8{
            "mlx_clear_window.c",
            "mlx_destroy_display.c",
            "mlx_destroy_image.c",
            "mlx_destroy_window.c",
            "mlx_expose_hook.c",
            "mlx_ext_randr.c",
            "mlx_flush_event.c",
            "mlx_get_color_value.c",
            "mlx_get_data_addr.c",
            "mlx_hook.c",
            "mlx_init.c",
            "mlx_int_anti_resize_win.c",
            "mlx_int_do_nothing.c",
            "mlx_int_get_visual.c",
            "mlx_int_param_event.c",
            "mlx_int_set_win_event_mask.c",
            "mlx_int_str_to_wordtab.c",
            "mlx_int_wait_first_expose.c",
            "mlx_key_hook.c",
            "mlx_lib_xpm.c",
            "mlx_loop.c",
            "mlx_loop_hook.c",
            "mlx_mouse.c",
            "mlx_mouse_hook.c",
            "mlx_new_image.c",
            "mlx_new_window.c",
            "mlx_pixel_put.c",
            "mlx_put_image_to_window.c",
            "mlx_rgb.c",
            "mlx_screen_size.c",
            "mlx_set_font.c",
            "mlx_string_put.c",
            "mlx_xpm.c",
        },
        .flags = &[_][]const u8{},
        .language = std.Build.Module.CSourceLanguage.c,
    });

    const exe = b.addExecutable(.{
        .name = "Nes",
        .root_module = main_mod,
    });

    exe.linkSystemLibrary("X11");
    exe.linkSystemLibrary("Xext");
    exe.linkLibC();

    exe.addIncludePath(b.path("./lib/minilibx-linux/"));

    b.installArtifact(exe);

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
