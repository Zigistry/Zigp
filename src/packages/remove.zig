const std = @import("std");
const ansi = @import("ansi");
const hfs = @import("../libs/helper_functions.zig");
const types = @import("../types.zig");

pub fn remove_dependency(allocator: std.mem.Allocator, dependency_to_remove: []const u8) !void {
    {
        const file = try std.fs.cwd().openFile("./zigp.zon", .{ .mode = .read_write });
        defer file.close();

        const data_constu8 = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(data_constu8);

        const data = try allocator.dupeZ(u8, data_constu8);

        var zigp_zon_parsed = try hfs.parse_zigp_zon(allocator, data);

        defer {
            allocator.free(zigp_zon_parsed.zig_version.?);
            allocator.free(zigp_zon_parsed.zigp_version.?);
            var iterfree = zigp_zon_parsed.dependencies.iterator();
            while (iterfree.next()) |next| {
                allocator.free(next.key_ptr.*);
            }
            zigp_zon_parsed.dependencies.deinit(allocator);
        }
        var iter = zigp_zon_parsed.dependencies.iterator();

        while (iter.next()) |dependency| {
            if (std.mem.eql(u8, dependency.key_ptr.*, dependency_to_remove)) {
                if (zigp_zon_parsed.dependencies.swapRemove(dependency.key_ptr.*)) {
                    const to_write_to_file = try types.zigp_zon_to_string(zigp_zon_parsed, allocator);
                    try file.seekTo(0);
                    try file.setEndPos(0);
                    try file.writeAll(to_write_to_file);
                    std.debug.print("{s}Removed {s} dependency from {s}zigp.zon{s}.\n", .{ ansi.BOLD ++ ansi.BRIGHT_GREEN, dependency_to_remove, ansi.UNDERLINE, ansi.RESET });
                } else {
                    @panic("Unable to remove dependency.");
                }
            }
        }
    }
    {
        const file = try std.fs.cwd().openFile("./build.zig.zon", .{ .mode = .read_write });
        defer file.close();

        const data_constu8 = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(data_constu8);

        const data = try allocator.dupeZ(u8, data_constu8);

        var build_zig_zon_parsed = try hfs.parse_build_zig_zon(allocator, data);

        defer {
            allocator.free(build_zig_zon_parsed.version.?);
            var iterfree = build_zig_zon_parsed.dependencies.iterator();
            while (iterfree.next()) |next| {
                allocator.free(next.key_ptr.*);
            }
            build_zig_zon_parsed.dependencies.deinit(allocator);
        }
        var iter = build_zig_zon_parsed.dependencies.iterator();

        while (iter.next()) |dependency| {
            if (std.mem.eql(u8, dependency.key_ptr.*, dependency_to_remove)) {
                if (build_zig_zon_parsed.dependencies.swapRemove(dependency.key_ptr.*)) {
                    const to_write_to_file = try types.build_zig_zon_to_string(build_zig_zon_parsed, allocator);
                    try file.seekTo(0);
                    try file.setEndPos(0);
                    try file.writeAll(to_write_to_file);
                    std.debug.print("{s}Removed {s} dependency from {s}build.zig.zon{s}.\n", .{ ansi.BOLD ++ ansi.BRIGHT_GREEN, dependency_to_remove, ansi.UNDERLINE, ansi.RESET });
                } else {
                    @panic("Unable to remove dependency.");
                }
            }
        }
    }
}
