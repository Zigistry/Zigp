const std = @import("std");
const modules = @import("modules.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const modules_list = modules.buildModules(b, target, optimize);

    const exe = b.addExecutable(.{
        .name = "zigp",
        .root_module = modules_list.main,
    });

    exe.linkLibC();

    b.installArtifact(exe);

    const search_test_module = b.addModule("search-tests", .{ .root_source_file = .{ .cwd_relative = "tests/search_test.zig" }, .target = target, .optimize = optimize });
    search_test_module.addImport("search", modules_list.search);

    const search_tests = b.addTest(.{
        .root_module = search_test_module,
    });

    const run_search_tests = b.addRunArtifact(search_tests);

    // Test steps
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_search_tests.step);

    const search_test_step = b.step("test-search", "Run search tests only");
    search_test_step.dependOn(&run_search_tests.step);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
