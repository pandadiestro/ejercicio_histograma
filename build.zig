const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main_module = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{},
    });

    // ---
    // check step
    // ---
    const check_main = b.addExecutable(.{
        .name = "main",
        .root_module = main_module,
    });

    const check_compile = b.addInstallArtifact(check_main, .{});

    const run_check_step = b.step("check", "zls check");
    run_check_step.dependOn(&check_compile.step);

    // ---
    // main step
    // ---
    const build_main = b.addExecutable(.{
        .name = "main",
        .root_module = main_module,
    });

    b.installArtifact(build_main);

    const run_compile = b.addRunArtifact(build_main);
    if (b.args) |args| {
        run_compile.addArgs(args);
    }

    const run_step = b.step("run", "build and run the app");
    run_step.dependOn(&run_compile.step);
    run_step.dependOn(&build_main.step);
}
