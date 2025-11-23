const std = @import("std");
const ansi = @import("ansi");
const hfs = @import("../libs/helper_functions.zig");
const types = @import("../types.zig");

pub fn update_specific_packages(package_to_update: []const u8, allocator: std.mem.Allocator) !void {
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
        if (!std.mem.eql(u8, dependency_name, package_to_update)) {
            continue;
        }
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

                    const max_semver_version = hfs.semver_caret_max_range(try hfs.clean_and_parse_semver(next.value_ptr.version.?[1..]));

                    const versions = try hfs.fetch_versions(repo, allocator);

                    var selected_version_to_install_optional: ?[]const u8 = null;
                    // Going from big to small
                    // the moment we reach something that is less than max_semver_version, we break.
                    for (versions) |version| {
                        if (hfs.semver_x_greater_than_y(max_semver_version, hfs.clean_and_parse_semver(version) catch continue)) {
                            selected_version_to_install_optional = version;
                            break;
                        }
                    }
                    if (selected_version_to_install_optional) |selected_version_to_install| {
                        const tar_file_url = "https://github.com/{s}/archive/refs/tags/{s}.tar.gz";
                        const url_to_fetch = try std.fmt.allocPrint(allocator, tar_file_url, .{ repo_full_name, selected_version_to_install });
                        const res = try hfs.run_cli_command(&.{ "zig", "fetch", try std.fmt.allocPrint(allocator, "--save={s}", .{dependency_name}), url_to_fetch }, allocator, .no_read);
                        switch (res.Exited) {
                            0 => std.debug.print("{s}Updated: {s}{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, repo.full_name, ansi.RESET }),
                            else => std.debug.print("{s}Error while doing zig fetch.{s}\n", .{ ansi.BRIGHT_RED ++ ansi.BOLD, ansi.RESET }),
                        }
                    } else {
                        std.debug.print("{s} Is already up to date.\n", .{repo_full_name});
                    }
                },
                .latest_branching => {
                    std.debug.print("Latest branch: {s}\n", .{repo.full_name});
                    var branch_iter = std.mem.splitScalar(u8, next.value_ptr.version.?, '%');
                    _ = branch_iter.next().?;
                    const branch_name = branch_iter.next().?;
                    std.debug.print("Branch name: {s}\n", .{branch_name});
                    std.debug.print("Version name: {s}\n", .{next.value_ptr.version.?});
                    const tag_to_install = try std.fmt.allocPrint(allocator, "git+https://github.com/{s}#{s}", .{ repo.full_name, branch_name });
                    defer allocator.free(tag_to_install);

                    const process_to_get_fetch_hash = try hfs.run_cli_command(&.{ "zig", "fetch", tag_to_install }, allocator, .stdout);
                    switch (process_to_get_fetch_hash.Exited) {
                        0 => {
                            const process_to_get_commit_hash = try hfs.run_cli_command(&.{ "zig", "fetch", "--save", tag_to_install }, allocator, .stderr);

                            switch (process_to_get_commit_hash.Exited) {
                                0 => {
                                    std.debug.print("{s}Updated: {s}{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, repo.full_name, ansi.RESET });
                                },
                                else => return error.unknown,
                            }
                        },
                        else => return error.unknown,
                    }
                },
                .tilde_range => {
                    std.debug.print("Tilde branch: {s}\n", .{repo.full_name});
                    const max_semver_version = hfs.semver_tilde_max_range(try hfs.clean_and_parse_semver(next.value_ptr.version.?[1..]));
                    const versions = try hfs.fetch_versions(repo, allocator);

                    var selected_version_to_install_optional: ?[]const u8 = null;
                    // Going from big to small
                    // the moment we reach something that is less than max_semver_version, we break.
                    for (versions) |version| {
                        if (hfs.semver_x_greater_than_y(max_semver_version, hfs.clean_and_parse_semver(version) catch continue)) {
                            selected_version_to_install_optional = version;
                            break;
                        }
                    }
                    if (selected_version_to_install_optional) |selected_version_to_install| {
                        const tar_file_url = "https://github.com/{s}/archive/refs/tags/{s}.tar.gz";
                        const url_to_fetch = try std.fmt.allocPrint(allocator, tar_file_url, .{ repo_full_name, selected_version_to_install });
                        const res = try hfs.run_cli_command(&.{ "zig", "fetch", try std.fmt.allocPrint(allocator, "--save={s}", .{dependency_name}), url_to_fetch }, allocator, .no_read);
                        switch (res.Exited) {
                            0 => std.debug.print("{s}Updated: {s}{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, repo.full_name, ansi.RESET }),
                            else => std.debug.print("{s}Error while doing zig fetch.{s}\n", .{ ansi.BRIGHT_RED ++ ansi.BOLD, ansi.RESET }),
                        }
                    } else {
                        std.debug.print("{s} Is already up to date.\n", .{repo_full_name});
                    }
                },
                .range_based_versioning => {
                    std.debug.print("Ranged based versioning: {s}\n", .{repo.full_name});
                    const semver_version_range = try hfs.semver_parse_range_based(next.value_ptr.version.?);
                    const versions = try hfs.fetch_versions(repo, allocator);

                    var selected_version_to_install_optional: ?[]const u8 = null;
                    for (versions) |version| {
                        const ver = hfs.clean_and_parse_semver(version) catch continue;

                        if (hfs.semver_x_greater_than_or_equal_y(semver_version_range.max, ver) and hfs.semver_x_greater_than_or_equal_y(ver, semver_version_range.min)) {
                            selected_version_to_install_optional = version;
                            break;
                        }
                    }
                    if (selected_version_to_install_optional) |selected_version_to_install| {
                        const tar_file_url = "https://github.com/{s}/archive/refs/tags/{s}.tar.gz";
                        const url_to_fetch = try std.fmt.allocPrint(allocator, tar_file_url, .{ repo_full_name, selected_version_to_install });
                        const res = try hfs.run_cli_command(&.{ "zig", "fetch", try std.fmt.allocPrint(allocator, "--save={s}", .{dependency_name}), url_to_fetch }, allocator, .no_read);
                        switch (res.Exited) {
                            0 => std.debug.print("{s}Updated: {s}{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, repo.full_name, ansi.RESET }),
                            else => std.debug.print("{s}Error while doing zig fetch.{s}\n", .{ ansi.BRIGHT_RED ++ ansi.BOLD, ansi.RESET }),
                        }
                    } else {
                        std.debug.print("{s} Couldn't find a version within specified range.\n", .{repo_full_name});
                    }
                },
                .not_following_semver_name_exact_versioning, .exact_branching, .exact_versioning => {
                    // No need to update
                    std.debug.print("{s}{s}{s} has fixed version.\n", .{ ansi.BRIGHT_YELLOW ++ ansi.BOLD, repo.full_name, ansi.RESET });
                    //
                },
            }
        } else {
            @panic("Zigp only supports GitHub.");
        }
    }
}

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

                    const max_semver_version = hfs.semver_caret_max_range(try hfs.clean_and_parse_semver(next.value_ptr.version.?[1..]));

                    const versions = try hfs.fetch_versions(repo, allocator);

                    var selected_version_to_install_optional: ?[]const u8 = null;
                    // Going from big to small
                    // the moment we reach something that is less than max_semver_version, we break.
                    for (versions) |version| {
                        if (hfs.semver_x_greater_than_y(max_semver_version, hfs.clean_and_parse_semver(version) catch continue)) {
                            selected_version_to_install_optional = version;
                            break;
                        }
                    }
                    if (selected_version_to_install_optional) |selected_version_to_install| {
                        const tar_file_url = "https://github.com/{s}/archive/refs/tags/{s}.tar.gz";
                        const url_to_fetch = try std.fmt.allocPrint(allocator, tar_file_url, .{ repo_full_name, selected_version_to_install });
                        const res = try hfs.run_cli_command(&.{ "zig", "fetch", try std.fmt.allocPrint(allocator, "--save={s}", .{dependency_name}), url_to_fetch }, allocator, .no_read);
                        switch (res.Exited) {
                            0 => std.debug.print("{s}Updated: {s}{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, repo.full_name, ansi.RESET }),
                            else => std.debug.print("{s}Error while doing zig fetch.{s}\n", .{ ansi.BRIGHT_RED ++ ansi.BOLD, ansi.RESET }),
                        }
                    } else {
                        std.debug.print("{s} Is already up to date.\n", .{repo_full_name});
                    }
                },
                .latest_branching => {
                    std.debug.print("Latest branch: {s}\n", .{repo.full_name});
                    var branch_iter = std.mem.splitScalar(u8, next.value_ptr.version.?, '%');
                    _ = branch_iter.next().?;
                    const branch_name = branch_iter.next().?;
                    std.debug.print("Branch name: {s}\n", .{branch_name});
                    std.debug.print("Version name: {s}\n", .{next.value_ptr.version.?});
                    const tag_to_install = try std.fmt.allocPrint(allocator, "git+https://github.com/{s}#{s}", .{ repo.full_name, branch_name });
                    defer allocator.free(tag_to_install);

                    const process_to_get_fetch_hash = try hfs.run_cli_command(&.{ "zig", "fetch", tag_to_install }, allocator, .stdout);
                    switch (process_to_get_fetch_hash.Exited) {
                        0 => {
                            const process_to_get_commit_hash = try hfs.run_cli_command(&.{ "zig", "fetch", "--save", tag_to_install }, allocator, .stderr);

                            switch (process_to_get_commit_hash.Exited) {
                                0 => {
                                    std.debug.print("{s}Updated: {s}{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, repo.full_name, ansi.RESET });
                                },
                                else => return error.unknown,
                            }
                        },
                        else => return error.unknown,
                    }
                },
                .tilde_range => {
                    std.debug.print("Tilde branch: {s}\n", .{repo.full_name});
                    const max_semver_version = hfs.semver_tilde_max_range(try hfs.clean_and_parse_semver(next.value_ptr.version.?[1..]));
                    const versions = try hfs.fetch_versions(repo, allocator);

                    var selected_version_to_install_optional: ?[]const u8 = null;
                    // Going from big to small
                    // the moment we reach something that is less than max_semver_version, we break.
                    for (versions) |version| {
                        if (hfs.semver_x_greater_than_y(max_semver_version, hfs.clean_and_parse_semver(version) catch continue)) {
                            selected_version_to_install_optional = version;
                            break;
                        }
                    }
                    if (selected_version_to_install_optional) |selected_version_to_install| {
                        const tar_file_url = "https://github.com/{s}/archive/refs/tags/{s}.tar.gz";
                        const url_to_fetch = try std.fmt.allocPrint(allocator, tar_file_url, .{ repo_full_name, selected_version_to_install });
                        const res = try hfs.run_cli_command(&.{ "zig", "fetch", try std.fmt.allocPrint(allocator, "--save={s}", .{dependency_name}), url_to_fetch }, allocator, .no_read);
                        switch (res.Exited) {
                            0 => std.debug.print("{s}Updated: {s}{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, repo.full_name, ansi.RESET }),
                            else => std.debug.print("{s}Error while doing zig fetch.{s}\n", .{ ansi.BRIGHT_RED ++ ansi.BOLD, ansi.RESET }),
                        }
                    } else {
                        std.debug.print("{s} Is already up to date.\n", .{repo_full_name});
                    }
                },
                .range_based_versioning => {
                    std.debug.print("Ranged based versioning: {s}\n", .{repo.full_name});
                    const semver_version_range = try hfs.semver_parse_range_based(next.value_ptr.version.?);
                    const versions = try hfs.fetch_versions(repo, allocator);

                    var selected_version_to_install_optional: ?[]const u8 = null;
                    for (versions) |version| {
                        const ver = hfs.clean_and_parse_semver(version) catch continue;

                        if (hfs.semver_x_greater_than_or_equal_y(semver_version_range.max, ver) and hfs.semver_x_greater_than_or_equal_y(ver, semver_version_range.min)) {
                            selected_version_to_install_optional = version;
                            break;
                        }
                    }
                    if (selected_version_to_install_optional) |selected_version_to_install| {
                        const tar_file_url = "https://github.com/{s}/archive/refs/tags/{s}.tar.gz";
                        const url_to_fetch = try std.fmt.allocPrint(allocator, tar_file_url, .{ repo_full_name, selected_version_to_install });
                        const res = try hfs.run_cli_command(&.{ "zig", "fetch", try std.fmt.allocPrint(allocator, "--save={s}", .{dependency_name}), url_to_fetch }, allocator, .no_read);
                        switch (res.Exited) {
                            0 => std.debug.print("{s}Updated: {s}{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, repo.full_name, ansi.RESET }),
                            else => std.debug.print("{s}Error while doing zig fetch.{s}\n", .{ ansi.BRIGHT_RED ++ ansi.BOLD, ansi.RESET }),
                        }
                    } else {
                        std.debug.print("{s} Couldn't find a version within specified range.\n", .{repo_full_name});
                    }
                },
                .not_following_semver_name_exact_versioning, .exact_branching, .exact_versioning => {
                    // No need to update
                    std.debug.print("{s}{s}{s} has fixed version.\n", .{ ansi.BRIGHT_YELLOW ++ ansi.BOLD, repo.full_name, ansi.RESET });
                    //
                },
            }
        } else {
            @panic("Zigp only supports GitHub.");
        }
    }
}
