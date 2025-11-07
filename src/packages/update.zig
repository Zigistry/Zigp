const std = @import("std");
const ansi = @import("../libs/ansi_codes.zig");
const hfs = @import("../libs/helper_functions.zig");
const types = @import("../types.zig");

pub fn update_packages(allocator: std.mem.Allocator) !void {
    const file = try std.fs.cwd().openFile("./zigp.zon", .{ .mode = .read_write });
    defer file.close();

    const data_u8 = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(data_u8);

    const zigp_raw_data = try allocator.dupeZ(u8, data_u8);
    defer allocator.free(zigp_raw_data);

    var zigp_zon_parsed = try hfs.parse_zigp_zon(allocator, zigp_raw_data);
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
    while (iter.next()) |next| {
        const dependency_name = next.key_ptr.*;
        if (next.value_ptr.provider == .GitHub) {
            const repo_full_name = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ next.value_ptr.owner_name.?, next.value_ptr.repo_name.? });

            const repo: types.repository = .{
                .full_name = repo_full_name,
                .name = next.value_ptr.repo_name.?,
                .owner = next.value_ptr.owner_name.?,
                .provider = .GitHub,
            };

            switch (hfs.get_versioning_type(next.value_ptr.version.?)) {
                .any_latest => {
                    std.debug.print("Any latest update: {s}\n", .{repo.full_name});
                    const versions = try hfs.fetch_versions(repo, allocator);
                    const tar_file_url = "https://github.com/{s}/archive/refs/tags/{s}.tar.gz";
                    const url_to_fetch = try std.fmt.allocPrint(allocator, tar_file_url, .{ repo_full_name, versions[0] });
                    const res = try hfs.run_cli_command(&.{ "zig", "fetch", try std.fmt.allocPrint(allocator, "--save={s}", .{dependency_name}), url_to_fetch }, allocator, .no_read);
                    switch (res.Exited) {
                        0 => std.debug.print("{s}Updated: {s}{s}\n", .{ ansi.BRIGHT_RED ++ ansi.BOLD, repo.full_name, ansi.RESET }),
                        else => std.debug.print("{s}Error while doing zig fetch.{s}\n", .{ ansi.BRIGHT_RED ++ ansi.BOLD, ansi.RESET }),
                    }
                },
                .caret_range => {
                    // ------- //
                    std.debug.print("Caret update: {s}\n", .{repo.full_name});
                    //
                },
                .wrong_semver_name_exact_versioning, .exact_branching, .exact_versioning => {
                    // No need to update
                    std.debug.print("No update: {s}\n", .{repo.full_name});
                    //
                },
                .latest_branching => {
                    std.debug.print("Latest branch: {s}\n", .{repo.full_name});
                },
                .tilde_range => {
                    std.debug.print("Tilde branch: {s}\n", .{repo.full_name});
                },
                .range_based_versioning => {
                    std.debug.print("Ranged based versioning: {s}\n", .{repo.full_name});
                },
            }
        } else {
            @panic("Zigp only supports GitHub.");
        }
    }
}
