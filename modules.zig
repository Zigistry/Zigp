const std = @import("std");

pub fn buildModules(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) struct {
    ansi: *std.Build.Module,
    search: *std.Build.Module,
    main: *std.Build.Module,
} {
    const ansi_module = b.addModule("ansi", .{
        .root_source_file = .{ .cwd_relative = "src/libs/ansi_codes.zig" },
        .target = target,
        .optimize = optimize,
    });

    const search_module = b.addModule("search", .{
        .root_source_file = .{ .cwd_relative = "src/packages/search.zig" },
        .target = target,
        .optimize = optimize,
    });

    search_module.addImport("ansi", ansi_module);

    const main_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    main_module.addImport("search", search_module);
    main_module.addImport("ansi", ansi_module);

    return .{
        .ansi = ansi_module,
        .search = search_module,
        .main = main_module,
    };
}
