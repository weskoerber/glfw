const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "glfw3",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(.{ .path = "include" });
    lib.addIncludePath(.{ .path = "src" });
    lib.addCSourceFiles(.{ .files = &generic_src_files });
    lib.linkLibC();
    switch (target.result.os.tag) {
        .windows => {
            lib.addCSourceFiles(.{ .files = &windows_src_files });
            lib.linkSystemLibrary("gdi32");
            lib.defineCMacro("_GLFW_WIN32", null);
            lib.defineCMacro("UNICODE", null);
            lib.defineCMacro("_UNICODE", null);
        },
        else => unreachable,
    }
    lib.installHeadersDirectory("include/GLFW", "GLFW");
    // lib.installHeadersDirectory("deps/glad", "glad"); // doesn't work
    b.installArtifact(lib);
}

const generic_src_files = [_][]const u8{
    "src/context.c",
    "src/init.c",
    "src/input.c",
    "src/monitor.c",
    "src/platform.c",
    "src/vulkan.c",
    "src/window.c",
    "src/egl_context.c",
    "src/osmesa_context.c",
    "src/null_init.c",
    "src/null_monitor.c",
    "src/null_window.c",
    "src/null_joystick.c",
};

const windows_src_files = [_][]const u8{
    "src/win32_module.c",
    "src/win32_time.c",
    "src/win32_thread.c",

    "src/win32_init.c",
    "src/win32_joystick.c",
    "src/win32_monitor.c",
    "src/win32_window.c",
    "src/wgl_context.c",
};
