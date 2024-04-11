const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const build_x11 = b.option(bool, "build_x11", "Build X11 (default: yes)") orelse false;
    const build_wayland = b.option(bool, "build_wayland", "Build Wayland (default: yes)") orelse true;
    const gen_wayland = b.option(bool, "gen_wayland", "Run wayland-scanner to generate wayland protocol headers") orelse true;

    if (build_x11) {
        std.debug.panic("X11 not yet supported", .{});
    }

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
        .linux => {
            lib.addCSourceFiles(.{ .files = &linux_src_files });
            if (build_x11) {
                lib.defineCMacro("_GLFW_X11", null);
                lib.addCSourceFiles(.{ .files = &[_][]const u8{
                    "src/x11_init.c",
                    "src/x11_monitor.c",
                    "src/x11_window.c",
                    "src/xkb_unicode.c",
                    "src/glx_context.c",
                } });
            }

            if (build_wayland) {
                if (gen_wayland) {
                    try generateWaylandProtocols(b);
                }

                lib.defineCMacro("_GLFW_WAYLAND", null);
                lib.addIncludePath(.{ .path = "./deps/wayland/gen" });
                lib.installHeadersDirectory(.{ .path = "./deps/wayland/gen" }, "", .{});
                lib.addCSourceFiles(.{ .files = &[_][]const u8{
                    "src/wl_init.c",
                    "src/wl_monitor.c",
                    "src/wl_window.c",
                    "src/xkb_unicode.c",
                } });
            }
        },
        else => unreachable,
    }
    lib.installHeadersDirectory(.{ .path = "include/GLFW" }, "GLFW", .{});
    // lib.installHeadersDirectory("deps/glad", "glad"); // doesn't work
    b.installArtifact(lib);
}

fn generateWaylandProtocols(b: *std.Build) !void {
    std.fs.cwd().makeDir(b.pathFromRoot("./deps/wayland/gen/")) catch |err| {
        switch (err) {
            std.posix.MakeDirError.PathAlreadyExists => {},
            else => return err,
        }
    };

    for (wayland_protocols) |proto| {
        try generateWaylandProtocol(b, proto);
    }
}

fn generateWaylandProtocol(b: *std.Build, proto: []const u8) !void {
    var wl_client_header: [64]u8 = std.mem.zeroes([64]u8);
    var wl_client_code: [64]u8 = std.mem.zeroes([64]u8);

    _ = try b.findProgram(&[_][]const u8{"wayland-scanner"}, &[_][]const u8{});

    // Header file
    _ = std.mem.replace(
        u8,
        proto,
        ".xml",
        "-client-protocol.h",
        &wl_client_header,
    );

    // Code file
    _ = std.mem.replace(
        u8,
        proto,
        ".xml",
        "-client-protocol-code.h",
        &wl_client_code,
    );

    var path_to_proto = b.pathJoin(&[_][]const u8{
        b.pathFromRoot("."),
        "/deps/wayland",
        proto,
    });
    var dest_path = b.pathJoin(&[_][]const u8{
        b.pathFromRoot("."),
        "/deps/wayland/gen",
        &wl_client_header,
    });

    var result = try std.ChildProcess.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{
            "wayland-scanner",
            "client-header",
            path_to_proto,
            dest_path,
        },
    });
    std.heap.page_allocator.free(result.stdout);
    std.heap.page_allocator.free(result.stderr);

    path_to_proto = b.pathJoin(&[_][]const u8{
        b.pathFromRoot("."),
        "/deps/wayland",
        proto,
    });
    dest_path = b.pathJoin(&[_][]const u8{
        b.pathFromRoot("."),
        "/deps/wayland/gen",
        &wl_client_code,
    });

    result = try std.ChildProcess.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{
            "wayland-scanner",
            "private-code",
            path_to_proto,
            dest_path,
        },
    });
    std.heap.page_allocator.free(result.stdout);
    std.heap.page_allocator.free(result.stderr);
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

const linux_src_files = [_][]const u8{
    "src/posix_module.c",
    "src/posix_time.c",
    "src/posix_thread.c",

    "src/linux_joystick.c",
    "src/posix_poll.c",
};

const wayland_protocols = [_][]const u8{
    "wayland.xml",
    "viewporter.xml",
    "xdg-shell.xml",
    "idle-inhibit-unstable-v1.xml",
    "pointer-constraints-unstable-v1.xml",
    "relative-pointer-unstable-v1.xml",
    "fractional-scale-v1.xml",
    "xdg-activation-v1.xml",
    "xdg-decoration-unstable-v1.xml",
};
