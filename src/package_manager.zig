const std = @import("std");
const ansi = @import("./libs/ansi_codes.zig");
const hfs = @import("./libs/helper_functions.zig");
const types = @import("types.zig");

const url = "https://api.github.com/repos/{s}/releases";
const tar_file_url = "https://github.com/{s}/archive/refs/tags/{s}.tar.gz";

// https://github.com/RohanVashisht1234/zorsig/archive/refs/tags/v0.0.1.tar.gz
// https://github.com/{}/archive/refs/tags/{}.tar.gz

fn add_package_branch(repo: types.repository, allocator: std.mem.Allocator) !void {
    var branches = try hfs.fetch_branches(repo, allocator);
    const branches_list = branches.items;

    defer {
        for (branches_list) |item| {
            allocator.free(item);
        }
        branches.deinit(allocator);
    }

    {
        std.debug.print("{s}Please select the branch you want to install (type the index number):{s}\n", .{ ansi.BRIGHT_CYAN ++ ansi.BOLD, ansi.RESET });
        for (branches_list, 1..) |value, i| {
            std.debug.print("{}){s} {s}{s}\n", .{ i, ansi.BOLD, value, ansi.RESET });
        }
    }

    const user_branch_input = hfs.range_input_taker(1, branches_list.len);

    const tag_to_install = try std.fmt.allocPrint(allocator, "git+https://github.com/{s}#{s}", .{ repo.full_name, branches_list[user_branch_input - 1] });
    defer allocator.free(tag_to_install);

    var process_to_get_fetch_hash = std.process.Child.init(&[_][]const u8{ "zig", "fetch", tag_to_install }, allocator);
    process_to_get_fetch_hash.stdout_behavior = .Pipe;
    try process_to_get_fetch_hash.spawn();
    const fetch_hash = try process_to_get_fetch_hash.stdout.?.readToEndAlloc(allocator, std.math.maxInt(usize));

    defer allocator.free(fetch_hash);
    switch ((try process_to_get_fetch_hash.wait()).Exited) {
        0 => {
            std.debug.print("This is the thing: {s}", .{fetch_hash});
            // I will parse asdf to get the dependency's name and version!!!
            var iter = std.mem.splitScalar(u8, fetch_hash, '-');
            const name = iter.next().?;

            var new_process: std.process.Child = .init(&[_][]const u8{ "zig", "fetch", "--save", tag_to_install }, allocator);
            new_process.stderr_behavior = .Pipe;

            try new_process.spawn();

            const thing = try new_process.stderr.?.readToEndAlloc(allocator, std.math.maxInt(usize));
            defer allocator.free(thing);
            const new_term = try new_process.wait();

            const index = std.mem.indexOf(u8, thing, " to commit ") orelse return error.no_internet;

            const remaining_thing = thing[index + " to commit ".len ..];
            var iter5 = std.mem.splitScalar(u8, remaining_thing, '\n');

            switch (new_term.Exited) {
                0 => {
                    const file = try std.fs.cwd().openFile("./zigp.zon", .{ .mode = .read_write });
                    defer file.close();

                    // Read entire file into memory
                    const data_u8 = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
                    defer allocator.free(data_u8);

                    const zigp_raw_data = try allocator.dupeZ(u8, data_u8);
                    defer allocator.free(zigp_raw_data);
                    const commit_hash = iter5.next().?;

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

                    try zigp_zon_parsed.dependencies.put(allocator, name, .{
                        .owner_name = repo.owner,
                        .repo_name = repo.name,
                        .provider = repo.provider,
                        .version = try std.fmt.allocPrint(allocator, "%{s}#{s}", .{ branches_list[user_branch_input - 1], commit_hash }),
                    });
                    defer allocator.free(zigp_zon_parsed.dependencies.get(name).?.version.?);

                    try file.setEndPos(0);
                    try file.seekTo(0);
                    const res = try types.zigp_zon_to_string(zigp_zon_parsed, allocator);
                    defer allocator.free(res);
                    try file.writeAll(res);

                    hfs.print_suggestion(repo);
                },
                1 => std.debug.print("{s}Zig fetch returned an error. The process returned 1 exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, ansi.RESET }),
                else => std.debug.print("{s}Zig fetch returned an unknown error. It returned {} exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, new_term.Exited, ansi.RESET }),
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

    var process_to_get_fetch_hash = std.process.Child.init(&[_][]const u8{ "zig", "fetch", tag_to_install }, allocator);
    process_to_get_fetch_hash.stdout_behavior = .Pipe;
    try process_to_get_fetch_hash.spawn();
    const fetch_hash = try process_to_get_fetch_hash.stdout.?.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(fetch_hash);
    switch ((try process_to_get_fetch_hash.wait()).Exited) {
        0 => {},
        else => {
            std.debug.print("{s}Zig fetch returned an error!{s}", .{ ansi.BRIGHT_RED, ansi.RESET });
            return;
        },
    }

    var iter = std.mem.splitScalar(u8, fetch_hash, '-');
    const name = iter.next().?;

    var process: std.process.Child = .init(&[_][]const u8{ "zig", "fetch", "--save", tag_to_install }, allocator);
    switch ((try process.spawnAndWait()).Exited) {
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

            try zigp_zon_parsed.dependencies.put(allocator, name, .{
                .owner_name = repo.owner,
                .repo_name = repo.name,
                .provider = repo.provider,
                .version = try std.fmt.allocPrint(allocator, "^{s}", .{release_versions_list[user_select_number - 2]}),
            });
            defer allocator.free(zigp_zon_parsed.dependencies.get(name).?.version.?);

            defer zigp_zon_parsed.dependencies.deinit(allocator);

            try file.setEndPos(0);
            try file.seekTo(0);
            const res = try types.zigp_zon_to_string(zigp_zon_parsed, allocator);
            defer allocator.free(res);
            try file.writeAll(res);

            hfs.print_suggestion(repo);
        },
        1 => std.debug.print("{s}Zig fetch returned an error. The process returned 1 exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, ansi.RESET }),
        else => std.debug.print("{s}Zig fetch returned an unknown error.{s}\n", .{ ansi.RED ++ ansi.BOLD, ansi.RESET }),
    }
}

pub fn add_package(repo: types.repository, allocator: std.mem.Allocator) !void {
    if (!hfs.file_exists("zigp.zon")) {
        std.debug.print("{s}zigp.zon not found{s}", .{ ansi.BRIGHT_RED, ansi.RESET });
        std.debug.print("{s}Info:{s} please run {s}zigp init{s} to create one.", .{ ansi.BRIGHT_CYAN, ansi.RESET, ansi.BRIGHT_YELLOW, ansi.RESET });
        return;
    }

    if (!hfs.file_exists("build.zig.zon")) {
        std.debug.print("{s}build.zig.zon not found{s}", .{ ansi.BRIGHT_RED, ansi.RESET });
        std.debug.print("{s}Info:{s} please run {s}zig init{s} to create one.", .{ ansi.BRIGHT_CYAN, ansi.RESET, ansi.BRIGHT_YELLOW, ansi.RESET });
        return;
    }

    var versions = hfs.fetch_versions(repo, allocator) catch return;
    const release_versions_list = versions.items;

    defer {
        for (release_versions_list) |item| {
            allocator.free(item);
        }
        versions.deinit(allocator);
    }

    {
        std.debug.print("{s}Installing {s}{s}{s}\n", .{ ansi.YELLOW, ansi.UNDERLINE, repo.full_name, ansi.RESET });
        std.debug.print("{s}Please select the version you want to install (type the index number):{s}\n", .{ ansi.BRIGHT_CYAN ++ ansi.BOLD, ansi.RESET });

        std.debug.print("1){s} Install a branch{s}\n", .{ ansi.BOLD, ansi.RESET });
        if (release_versions_list.len == 0) {
            std.debug.print("{s}Info:{s} This package has no releases.\n", .{ ansi.BRIGHT_CYAN, ansi.RESET });
        }
        for (release_versions_list, 2..) |value, i| {
            std.debug.print("{}){s} {s}{s}\n", .{ i, ansi.BOLD, value, ansi.RESET });
        }
    }

    const user_select_number = hfs.range_input_taker(1, release_versions_list.len + 1);

    switch (user_select_number) {
        1 => try add_package_branch(repo, allocator),
        else => try add_package_release_version(repo, allocator, user_select_number, release_versions_list),
    }
}

pub fn info(repo: types.repository, allocator: std.mem.Allocator) !void {
    var versions = try hfs.fetch_versions(repo, allocator);
    defer {
        const items = versions.items;
        for (items) |item| {
            allocator.free(item);
        }
        versions.deinit(allocator);
    }

    var github_info = try hfs.fetch_info_from_github(repo, allocator);
    defer {
        allocator.free(github_info.license);
        allocator.free(github_info.description);
        const items = github_info.topics.items;
        for (items) |item| {
            allocator.free(item);
        }
        github_info.topics.deinit(allocator);
    }

    const version = switch (versions.items.len) {
        1 => "latest (unstable) no releases found.",
        else => versions.items[1],
    };
    std.debug.print("{s}{s}{s}", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, repo.full_name, ansi.RESET });
    for (github_info.topics.items, 1..) |topic, i| {
        if (i == 6) break;
        std.debug.print(" {s}#{s}{s}", .{ ansi.BRIGHT_CYAN ++ ansi.UNDERLINE ++ ansi.BOLD, topic, ansi.RESET });
    }
    std.debug.print("\n", .{});
    std.debug.print("{s}\n", .{github_info.description});
    std.debug.print("{s}license{s}: {s}{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, ansi.RESET, github_info.license, ansi.RESET });
    std.debug.print("{s}version{s}: {s}{s}{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, ansi.RESET, ansi.BOLD ++ ansi.BRIGHT_YELLOW, version, ansi.RESET });
    std.debug.print("{s}repository{s}: https://github.com/{s}{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, ansi.RESET, repo.full_name, ansi.RESET });
    std.debug.print("{s}zigistry.dev{s}: https://zigistry.dev/{s}/{s}/{s}{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, ansi.RESET, "packages", "github", repo.full_name, ansi.RESET });
}

pub fn update_packages(allocator: std.mem.Allocator) !void {
    const file = try std.fs.cwd().openFile("./build.zig.zon", .{});
    defer file.close();

    // Read entire file into memory
    const data = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(data);

    const new_string = try allocator.dupeZ(u8, data);
    defer allocator.free(new_string);

    var parsed = try hfs.parse_build_zig_zon(allocator, new_string);
    defer {
        if (parsed.name) |name| allocator.free(name);
        if (parsed.version) |version| allocator.free(version);
    }

    std.debug.print("{?s}\n", .{parsed.name});
    std.debug.print("{?s}\n", .{parsed.version});

    var it = parsed.dependencies.iterator();
    defer parsed.dependencies.deinit(allocator);
    while (it.next()) |dependency| {
        std.debug.print("{s}\n", .{dependency.key_ptr.*});
        std.debug.print("{?s}\n", .{dependency.value_ptr.url});
        if (dependency.value_ptr.url) |url_| {
            if (std.mem.startsWith(u8, url_, "git+")) {
                // must be a direct github link, just wanna update
                // After testing a lot, I found out that I can
                // just remove the part after # if it is there
                // and run zig fetch on the remaining part
                // it will update it to the latest commit.
                // Suppose if this was the url:
                // git+https://github.com/capy-ui/capy?ref=master#some_commit
                // we just get this part
                // git+https://github.com/capy-ui/capy?ref=master
                // and run zig fetch on it
                // REMEMBER! to use double quotes around it "git+https://github.com/capy-ui/capy?ref=master"
                // because my terminal was giving me error like error: ref not found: main
                // After adding double quote, it worked.
                var iter = std.mem.splitScalar(u8, url_, '#');
                const url_we_need = iter.next().?;
                var process = std.process.Child.init(&[_][]const u8{ "zig", "fetch", "--save", url_we_need }, allocator);
                const term = try process.spawnAndWait();
                switch (term.Exited) {
                    0 => std.debug.print("{s}Successfully Updated {s}.{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, url_we_need, ansi.RESET }),
                    1 => std.debug.print("{s}Zig fetch returned an error. The process returned 1 exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, ansi.RESET }),
                    else => std.debug.print("{s}Zig fetch returned an unknown error. It returned {} exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, term.Exited, ansi.RESET }),
                }
            } else if (std.mem.endsWith(u8, url_, ".tar.gz") and std.mem.startsWith(u8, url_, "https://")) {
                // if the url is like:
                // https://github.com/zigzap/zap/archive/refs/tags/v0.11.0.tar.gz
                // I only need https://github.com/zigzap/zap/archive/refs/tags/
                var front_url = std.mem.splitBackwardsScalar(u8, url_, '/');
                const current_tag_version = front_url.next().?;
                std.debug.print("Currently at: {s}", .{current_tag_version});
                const new_url_without_https = front_url.rest()[8..];
                const new_url = front_url.rest();
                // Now I also need https://github.com/zigzap/zap/ to fetch the versions.
                // for that I think I can do .next 2 times.
                var iter = std.mem.splitScalar(u8, new_url_without_https, '/');
                const provider = iter.next().?;
                if (!std.mem.eql(u8, provider, "github.com")) {
                    return error.unknown_provider;
                }
                const owner_name = iter.next().?;
                const repo_name = iter.next().?;
                const repo_full_name = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ owner_name, repo_name });
                const versions = try hfs.fetch_versions(.{ .full_name = repo_full_name, .name = repo_name, .owner = owner_name, .provider = .GitHub }, allocator);
                const latest_version = versions.items[1];
                std.debug.print("Going to: {s}", .{latest_version});
                const resulting = try std.fmt.allocPrint(allocator, "{s}/{s}.tar.gz", .{ new_url, latest_version });
                var process = std.process.Child.init(&[_][]const u8{ "zig", "fetch", "--save", resulting }, allocator);
                const term = try process.spawnAndWait();
                switch (term.Exited) {
                    0 => std.debug.print("{s}Successfully Updated {s}.{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, repo_full_name, ansi.RESET }),
                    1 => std.debug.print("{s}Zig fetch returned an error. The process returned 1 exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, ansi.RESET }),
                    else => std.debug.print("{s}Zig fetch returned an unknown error. It returned {} exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, term.Exited, ansi.RESET }),
                }
            }
        }
        if (dependency.value_ptr.url) |url_| allocator.free(url_);

        std.debug.print("{?s}\n", .{dependency.value_ptr.hash});
        if (dependency.value_ptr.hash) |hash| allocator.free(hash);
        allocator.free(dependency.key_ptr.*);
        std.debug.print("{?s}\n", .{dependency.value_ptr.path});
        std.debug.print("{?}\n", .{dependency.value_ptr.lazy});
    }
}

pub fn install_app(repo: types.repository, allocator: std.mem.Allocator) !void {
    const stdin = std.fs.File.stdin();

    var versions = hfs.fetch_versions(repo, allocator) catch return;

    const items = versions.items;

    defer {
        for (items) |item| {
            allocator.free(item);
        }
        versions.deinit(allocator);
    }

    std.debug.print("{s}Installing {s}{s}{s}\n", .{ ansi.YELLOW, ansi.UNDERLINE, repo.full_name, ansi.RESET });
    std.debug.print("{s}Please select the version you want to install (type the index number):{s}\n", .{ ansi.BRIGHT_CYAN ++ ansi.BOLD, ansi.RESET });

    for (items, 1..) |value, i| {
        std.debug.print("{}){s} {s}{s}\n", .{ i, ansi.BOLD, value, ansi.RESET });
    }

    outer: while (true) {
        std.debug.print("{s}>>>{s} ", .{ ansi.BRIGHT_CYAN, ansi.RESET });

        var buf: [16]u8 = undefined;

        const len = try stdin.read(&buf);

        var input = buf[0..len];

        if (input.len == 0) {
            std.debug.print("{s}Error:{s} No input entered.\n", .{ ansi.RED ++ ansi.BOLD, ansi.RESET });
            continue :outer;
        }

        if (input.len > 0 and (input[input.len - 1] == '\n' or input[input.len - 1] == '\r')) {
            input = input[0 .. input.len - 1];
        }

        for (input) |char| {
            if (!std.ascii.isDigit(char)) {
                std.debug.print("{s}Error:{s} Non charater input recieved.\n", .{ ansi.RED ++ ansi.BOLD, ansi.RESET });
                continue :outer;
            }
        }

        const number = try std.fmt.parseInt(u16, input, 10);

        if (number < 1 or number > items.len) {
            std.debug.print("{s}Error:{s} Number selection is out of range.\n", .{ ansi.RED ++ ansi.BOLD, ansi.RESET });
            continue;
        }

        const tag_to_install = switch (number) {
            1 => null,
            else => items[number - 1],
        };
        if (tag_to_install) |tag_to_install_not_null| {
            std.debug.print("{s}Installing application: {s}{s}{s}\n", .{ ansi.BRIGHT_YELLOW, ansi.UNDERLINE, items[number - 1], ansi.RESET });
            const sh = try std.fmt.allocPrint(allocator,
                \\export TMP_DIR=$(mktemp -d) &&
                \\echo "Created: $TMP_DIR" &&
                \\cd "$TMP_DIR" || exit 1 &&
                \\git clone https://github.com/{s}.git --depth=1 --branch {s} &&
                \\cd {s} || exit 1
                \\zig build install --prefix $HOME/.local/zigp
            , .{ repo.full_name, tag_to_install_not_null, repo.name });
            defer allocator.free(sh);
            var process = std.process.Child.init(&[_][]const u8{ "sh", "-c", sh }, allocator);
            const term = try process.spawnAndWait();
            switch (term.Exited) {
                0 => {},
                1 => {
                    std.debug.print("{s}Zig fetch returned an error. The process returned 1 exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, ansi.RESET });
                    return;
                },
                else => {
                    std.debug.print("{s}Zig fetch returned an unknown error. It returned {} exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, term.Exited, ansi.RESET });
                    return;
                },
            }
        } else {
            std.debug.print("{s}Installing application: {s}{s}{s}\n", .{ ansi.BRIGHT_YELLOW, ansi.UNDERLINE, items[number - 1], ansi.RESET });
            const sh = try std.fmt.allocPrint(allocator,
                \\export TMP_DIR=$(mktemp -d) &&
                \\echo "Created: $TMP_DIR" &&
                \\cd "$TMP_DIR" || exit 1 &&
                \\git clone https://github.com/{s}.git --depth=1 &&
                \\cd {s} || exit 1
                \\zig build install --prefix $HOME/.local/zigp
            , .{ repo.full_name, repo.name });
            defer allocator.free(sh);
            var process = std.process.Child.init(&[_][]const u8{ "sh", "-c", sh }, allocator);
            const term = try process.spawnAndWait();
            switch (term.Exited) {
                0 => {},
                1 => {
                    std.debug.print("{s}Zig fetch returned an error. The process returned 1 exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, ansi.RESET });
                    return;
                },
                else => {
                    std.debug.print("{s}Zig fetch returned an unknown error. It returned {} exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, term.Exited, ansi.RESET });
                    return;
                },
            }
        }
        const path_export =
            \\if [[ ":$PATH:" != *":$HOME/.local/zigp/bin:"* ]]; then
            \\    echo 'export PATH="$HOME/.local/zigp/bin:$PATH"' >> $HOME/.bashrc 2>/dev/null || true
            \\    echo 'export PATH="$HOME/.local/zigp/bin:$PATH"' >> $HOME/.zshrc 2>/dev/null || true
            \\    echo "Added $HOME/.local/zigp to your PATH (will apply on next shell start)"
            \\fi
            \\
        ;

        var process = std.process.Child.init(&[_][]const u8{ "sh", "-c", path_export }, allocator);
        const term = try process.spawnAndWait();

        switch (term.Exited) {
            0 => std.debug.print("{s}Installed {s}{s}{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, ansi.RESET ++ ansi.BRIGHT_YELLOW ++ ansi.UNDERLINE, repo.full_name, ansi.RESET }),
            else => std.debug.print("Error while exporting app to PATH.", .{}),
        }
        break;
    }
}
