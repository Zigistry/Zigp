const std = @import("std");
const ansi = @import("ansi");
const hfs = @import("../libs/helper_functions.zig");
const types = @import("../types.zig");

const url = "https://api.github.com/repos/{s}/releases";
const tar_file_url = "https://github.com/{s}/archive/refs/tags/{s}.tar.gz";

// https://github.com/RohanVashisht1234/zorsig/archive/refs/tags/v0.0.1.tar.gz
// https://github.com/{}/archive/refs/tags/{}.tar.gz

fn add_package_branch(repo: types.repository, allocator: std.mem.Allocator) !void {
    const branches_list = try hfs.fetch_branches(repo, allocator);

    defer for (branches_list) |item| {
        allocator.free(item);
    };

    std.debug.print("{s}Please select the branch you want to install (type the index number):{s}\n", .{ ansi.BRIGHT_CYAN ++ ansi.BOLD, ansi.RESET });
    for (branches_list, 1..) |value, i| {
        std.debug.print("{}){s} {s}{s}\n", .{ i, ansi.BOLD, value, ansi.RESET });
    }

    const user_branch_input = hfs.range_input_taker(1, branches_list.len);

    const tag_to_install = try std.fmt.allocPrint(allocator, "git+https://github.com/{s}#{s}", .{ repo.full_name, branches_list[user_branch_input - 1] });
    defer allocator.free(tag_to_install);

    const process_to_get_fetch_hash = try hfs.run_cli_command(&.{ "zig", "fetch", tag_to_install }, allocator, .stdout);

    switch (process_to_get_fetch_hash.Exited) {
        0 => {
            const process_to_get_commit_hash = try hfs.run_cli_command(&.{ "zig", "fetch", "--save", tag_to_install }, allocator, .stderr);
            const details_from_hash = try hfs.parse_hash(process_to_get_fetch_hash.text);

            switch (process_to_get_commit_hash.Exited) {
                0 => {
                    const file = try std.fs.cwd().openFile("./zigp.zon", .{ .mode = .read_write });
                    defer file.close();

                    // Read entire file into memory
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

                    try zigp_zon_parsed.dependencies.put(allocator, details_from_hash.package_name, .{
                        .owner_name = repo.owner,
                        .repo_name = repo.name,
                        .provider = repo.provider,
                        .version = try std.fmt.allocPrint(allocator, "%{s}", .{branches_list[user_branch_input - 1]}),
                    });
                    defer allocator.free(zigp_zon_parsed.dependencies.get(details_from_hash.package_name).?.version.?);
                    try file.seekTo(0);
                    try file.setEndPos(0);
                    const res = try types.zigp_zon_to_string(zigp_zon_parsed, allocator);
                    defer allocator.free(res);
                    try file.writeAll(res);

                    hfs.print_suggestion(details_from_hash);
                },
                1 => std.debug.print("{s}Zig fetch returned an error. The process returned 1 exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, ansi.RESET }),
                else => std.debug.print("{s}Zig fetch returned an unknown error. It returned {} exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, process_to_get_commit_hash.Exited, ansi.RESET }),
            }
        },
        else => {
            std.debug.print("Fetch returned some error", .{});
        },
    }
}

fn add_package_release_version(repo: types.repository, allocator: std.mem.Allocator, user_select_number: usize, release_versions_list: [][]const u8) !void {
    const tag_to_install = try std.fmt.allocPrint(allocator, tar_file_url, .{ repo.full_name, release_versions_list[user_select_number - 2] });
    defer allocator.free(tag_to_install);

    std.debug.print("{s}Adding package: {s}{s}{s}\n", .{ ansi.BRIGHT_YELLOW, ansi.UNDERLINE, release_versions_list[user_select_number - 2], ansi.RESET });

    const process_to_get_fetch_hash = try hfs.run_cli_command(&.{ "zig", "fetch", tag_to_install }, allocator, .stdout);

    switch (process_to_get_fetch_hash.Exited) {
        0 => if (std.mem.startsWith(u8, process_to_get_fetch_hash.text, "N-V-")) {
            std.debug.print("{s}Zig fetch returned a specific kind of hash which indicates the remote package doesn't has a build.zig.zon. Can't install this package.{s}\n", .{ ansi.BRIGHT_RED, ansi.RESET });
            return;
        },
        else => {
            std.debug.print("{s}Zig fetch returned an error!{s}", .{ ansi.BRIGHT_RED, ansi.RESET });
            return;
        },
    }

    const parsed_fetch_hash = try hfs.parse_hash(process_to_get_fetch_hash.text);

    const process = try hfs.run_cli_command(&.{ "zig", "fetch", "--save", tag_to_install }, allocator, .no_read);
    switch (process.Exited) {
        0 => {
            const file = try std.fs.cwd().openFile("./zigp.zon", .{ .mode = .read_write });
            defer file.close();

            // Read entire file into memory
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

            const cleaned_semver_optional = hfs.clean_and_parse_semver(release_versions_list[user_select_number - 2]);

            if (cleaned_semver_optional) |cleaned_semver| {
                try zigp_zon_parsed.dependencies.put(allocator, parsed_fetch_hash.package_name, .{
                    .owner_name = repo.owner,
                    .repo_name = repo.name,
                    .provider = repo.provider,
                    .version = try std.fmt.allocPrint(allocator, "^{s}", .{try types.semver_to_string(cleaned_semver, allocator)}),
                });
            } else |_| {
                try zigp_zon_parsed.dependencies.put(allocator, parsed_fetch_hash.package_name, .{
                    .owner_name = repo.owner,
                    .repo_name = repo.name,
                    .provider = repo.provider,
                    .version = try std.fmt.allocPrint(allocator, "|{s}", .{release_versions_list[user_select_number - 2]}),
                });
            }
            defer allocator.free(zigp_zon_parsed.dependencies.get(parsed_fetch_hash.package_name).?.version.?);
            try file.seekTo(0);
            try file.setEndPos(0);
            const res = try types.zigp_zon_to_string(zigp_zon_parsed, allocator);
            defer allocator.free(res);
            try file.writeAll(res);

            hfs.print_suggestion(parsed_fetch_hash);
        },
        1 => std.debug.print("{s}Zig fetch returned an error. The process returned 1 exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, ansi.RESET }),
        else => std.debug.print("{s}Zig fetch returned an unknown error.{s}\n", .{ ansi.RED ++ ansi.BOLD, ansi.RESET }),
    }
}

pub fn add_package(repo: types.repository, allocator: std.mem.Allocator) !void {
    if (!hfs.file_exists("zigp.zon")) {
        std.debug.print("{s}Error:{s} zigp.zon not found.\n", .{ ansi.BRIGHT_RED ++ ansi.BOLD, ansi.RESET });
        std.debug.print("{s}Info:{s} please run {s}zigp init{s} to create one.\n", .{ ansi.BRIGHT_CYAN, ansi.RESET, ansi.BRIGHT_YELLOW, ansi.RESET });
        return;
    }

    if (!hfs.file_exists("build.zig.zon")) {
        std.debug.print("{s}build.zig.zon not found{s}\n", .{ ansi.BRIGHT_RED, ansi.RESET });
        std.debug.print("{s}Info:{s} please run {s}zig init{s} to create one.\n", .{ ansi.BRIGHT_CYAN, ansi.RESET, ansi.BRIGHT_YELLOW, ansi.RESET });
        return;
    }

    const release_versions_list = hfs.fetch_versions(repo, allocator) catch return;

    defer for (release_versions_list) |item| {
        allocator.free(item);
    };

    std.debug.print("{s}Repository: {s}https://github.com/{s}{s}\n", .{ ansi.YELLOW, ansi.UNDERLINE, repo.full_name, ansi.RESET });
    std.debug.print("{s}Please select the version you want to install (type the index number):{s}\n", .{ ansi.BRIGHT_CYAN ++ ansi.BOLD, ansi.RESET });

    std.debug.print("1){s} Install a branch{s}\n", .{ ansi.BOLD, ansi.RESET });
    if (release_versions_list.len == 0) {
        std.debug.print("{s}Info:{s} This package has no releases.\n", .{ ansi.BRIGHT_CYAN, ansi.RESET });
    }
    for (release_versions_list, 2..) |value, i| {
        std.debug.print("{}){s} {s}{s}\n", .{ i, ansi.BOLD, value, ansi.RESET });
    }

    const user_select_number = hfs.range_input_taker(1, release_versions_list.len + 1);

    switch (user_select_number) {
        1 => try add_package_branch(repo, allocator),
        else => try add_package_release_version(repo, allocator, user_select_number, release_versions_list),
    }
}
