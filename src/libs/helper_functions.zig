const std = @import("std");
const ansi = @import("./ansi_codes.zig");
const types = @import("../types.zig");
const display = @import("display.zig");

const MAX_ALLOWED_REPO_NAME_LENGTH = 2000;
const releases_url = "https://api.github.com/repos/{s}/releases";
const branches_url = "https://api.github.com/repos/{s}/branches";
const tar_file_url = "https://github.com/{s}/archive/refs/tags/{s}.tar.gz";

const in = std.fs.File.stdin();

pub fn get_versioning_type(version: []const u8) types.update {
    return switch (version[0]) {
        '^' => .caret_range,
        '~' => .tilde_range,
        '|' => .wrong_semver_name_exact_versioning,
        '*' => .any_latest,
        '%' => .latest_branching,
        '=' => switch (version[1]) {
            '=' => switch (version[2]) {
                0...9 => .exact_versioning,
                '%' => .exact_branching,
                else => @panic("unable to parse"),
            },
            else => @panic("unable to parse"),
        },
        '>', '<' => .range_based_versioning,
        else => unreachable,
    };
}

pub fn yes_no_input_taker() bool {
    var buf: [2]u8 = undefined;
    var reader = in.reader(&buf);
    const user_input = reader.interface.takeDelimiterExclusive('\n') catch return false;
    return user_input[0] == 'y' or user_input[0] == 'Y';
}

pub fn clean_and_parse_semver(sermver_as_string_: []const u8) !types.semver {
    var semver_as_string = sermver_as_string_;
    if (semver_as_string[0] == 'v') {
        semver_as_string = sermver_as_string_[1..];
    }
    var iter = std.mem.splitAny(u8, semver_as_string, ".+-");

    const major = if (iter.next()) |major| major else return error.invalid_semver_recieved;
    const minor = if (iter.next()) |minor| minor else return error.invalid_semver_recieved;
    const patch = if (iter.next()) |patch| patch else return error.invalid_semver_recieved;

    return .{
        .major = try std.fmt.parseInt(u32, major, 10),
        .minor = try std.fmt.parseInt(u32, minor, 10),
        .patch = try std.fmt.parseInt(u32, patch, 10),
        .remaining = iter.rest(),
    };
}

test "parse_semver" {
    const res = try clean_and_parse_semver("0.0.0");
    const res2 = try clean_and_parse_semver("v0.0.0");
    const res3 = try clean_and_parse_semver("1.0.0+exp.sha.5114f85");
    const res4 = try clean_and_parse_semver("200.000.900+exp.sha.5114f85");

    std.debug.print("{any}\n", .{res});
    std.debug.print("{any}\n", .{res2});
    std.debug.print("{any}\n", .{res3});
    std.debug.print("{any}\n", .{res4});
}

pub fn parse_hash(hash: []const u8) !struct {
    package_name: []const u8,
    version: types.semver,
} {
    var iter = std.mem.splitScalar(u8, hash, '-');
    const name = iter.next().?;
    const version = iter.next().?; // I don't think i'll use build.zig.zon's version.

    return .{
        .package_name = name,
        .version = try clean_and_parse_semver(version),
    };
}

pub fn run_cli_command(
    command: []const []const u8,
    allocator: std.mem.Allocator,
    mode: enum { stdout, stderr, no_read },
) !struct {
    text: []const u8,
    Exited: u8,
} {
    var process: std.process.Child = .init(command, allocator);

    switch (mode) {
        .stdout => process.stdout_behavior = .Pipe,
        .stderr => process.stderr_behavior = .Pipe,
        .no_read => {},
    }

    try process.spawn();

    const result =
        switch (mode) {
            .stdout => try process.stdout.?.readToEndAlloc(allocator, std.math.maxInt(usize)),
            .stderr => try process.stderr.?.readToEndAlloc(allocator, std.math.maxInt(usize)),
            .no_read => "",
        };

    return .{
        .Exited = (try process.wait()).Exited,
        .text = result,
    };
}

pub fn print_suggestion(repo: types.repository) void {
    std.debug.print("{s}Successfully installed {s}.{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, repo.full_name, ansi.RESET });
    std.debug.print("{s}✧ Suggestion:{s}\n", .{ ansi.BRIGHT_MAGENTA ++ ansi.BOLD, ansi.RESET });
    std.debug.print("You can add these lines to your build.zig (just above the b.installArtifact(exe) line).\n\n", .{});
    const suggestor =
        ansi.BRIGHT_BLUE ++ "const" ++ ansi.BRIGHT_CYAN ++ " {s} " ++ ansi.RESET ++ "= " ++ ansi.BRIGHT_CYAN ++ "b" ++ ansi.RESET ++ "." ++ ansi.BRIGHT_YELLOW ++ "dependency" ++ ansi.RESET ++ "(" ++ ansi.BRIGHT_GREEN ++ "\"{s}\"" ++ ansi.RESET ++ ", ." ++ ansi.BRIGHT_MAGENTA ++ "{{}}" ++ ansi.RESET ++ ");" ++ "\n" ++
        ansi.BRIGHT_CYAN ++ "exe" ++ ansi.RESET ++ "." ++ ansi.BRIGHT_BLUE ++ "root_module" ++ ansi.RESET ++ "." ++ ansi.BRIGHT_YELLOW ++ "addImport" ++ ansi.RESET ++ "(" ++ ansi.BRIGHT_GREEN ++ "\"{s}\"" ++ ansi.RESET ++ "," ++ ansi.BRIGHT_CYAN ++ " {s}" ++ ansi.RESET ++ "." ++ ansi.BRIGHT_YELLOW ++ "module" ++ ansi.RESET ++ "(" ++ ansi.BRIGHT_GREEN ++ "\"{s}\"" ++ ansi.RESET ++ "));\n";
    std.debug.print(suggestor, .{ repo.name, repo.name, repo.name, repo.name, repo.name });
}

pub fn file_exists(file: []const u8) bool {
    var dir = std.fs.cwd().openDir(".", .{}) catch return false;
    defer dir.close();
    dir.access(file, .{}) catch return false;
    return true;
}

pub fn read_string(allocator: std.mem.Allocator) !u32 {
    var bufr = std.mem.zeroes([500]u8);
    var r = in.reader(&bufr);
    var alloc: std.io.Writer.Allocating = .init(allocator);
    _ = try r.interface.streamDelimiter(&alloc.writer, '\n');
    return alloc.written();
}

pub fn read_integer() !usize {
    var buf: [25]u8 = undefined;
    var reader = in.reader(&buf);
    const num_str = reader.interface.takeDelimiterExclusive('\n') catch return error.UnexpectedEos;
    return try std.fmt.parseInt(usize, num_str, 10);
}

pub fn fetch_versions(repo: types.repository, allocator: std.mem.Allocator) ![][]const u8 {
    // I am doing -2 for making sure {} is not included.
    if (releases_url.len + repo.full_name.len - 2 > MAX_ALLOWED_REPO_NAME_LENGTH) {
        @panic("The length of repo name is way too much long.");
    }

    var buf: [MAX_ALLOWED_REPO_NAME_LENGTH]u8 = undefined;
    const fetch_url = try std.fmt.bufPrintZ(&buf, releases_url, .{repo.full_name});

    var response = std.Io.Writer.Allocating.init(allocator);

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    defer response.deinit();

    const result = try client.fetch(.{
        .location = .{ .url = fetch_url },
        .response_writer = &response.writer,
    });

    switch (result.status) {
        .ok => {},
        .not_found => {
            std.debug.print("{s}Error: {s}\"{s}\"{s} is not a repo.\n", .{ ansi.RED ++ ansi.BOLD, ansi.BRIGHT_CYAN, repo.full_name, ansi.RESET });
            return error.invalid_responce;
        },
        else => {
            std.debug.print("{s}Didn't recieve a responce, please check your internet connection.{s}", .{ ansi.RED ++ ansi.BOLD, ansi.RESET });
            return error.invalid_responce;
        },
    }

    const body = response.written();

    if (body.len == 0 or body[0] != '[') {
        std.debug.print("{s}A non json responce was recieved which is most likely an error, responce recieved:\n{s}", .{ ansi.RED ++ ansi.BOLD, ansi.RESET });
        std.debug.print("{s}\n", .{body});
        return error.invalid_responce;
    }

    const json_handler: std.json.Parsed(std.json.Value) = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer json_handler.deinit();

    var list: std.ArrayList([]const u8) = .empty;

    const all_releases = json_handler.value.array.items;

    if (all_releases.len != 0) {
        for (all_releases) |single_release| {
            const tag = single_release.object.get("tag_name").?.string;
            const duplicated_tag_string = try allocator.dupe(u8, tag);
            try list.append(allocator, duplicated_tag_string);
        }
    }

    return try list.toOwnedSlice(allocator);
}

//  https://api.github.com/repos/rohanvashisht1234/zorsig/branches
pub fn fetch_branches(repo: types.repository, allocator: std.mem.Allocator) ![][]const u8 {
    // I am doing -2 for making sure {} is not included.
    if (branches_url.len + repo.full_name.len - 2 > MAX_ALLOWED_REPO_NAME_LENGTH) {
        @panic("The length of repo name is way too much long.");
    }

    var buf: [MAX_ALLOWED_REPO_NAME_LENGTH]u8 = undefined;
    const fetch_url = try std.fmt.bufPrintZ(&buf, branches_url, .{repo.full_name});

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var response = std.Io.Writer.Allocating.init(allocator);
    defer response.deinit();

    const result = try client.fetch(.{
        .location = .{ .url = fetch_url },
        .response_writer = &response.writer,
    });

    switch (result.status) {
        .ok => {},
        .not_found => {
            std.debug.print("{s}Error: {s}\"{s}\"{s} is not a repo.\n", .{ ansi.RED ++ ansi.BOLD, ansi.BRIGHT_CYAN, repo.full_name, ansi.RESET });
            return error.invalid_responce;
        },
        else => {
            std.debug.print("{s}Didn't recieve a responce, please check your internet connection.{s}", .{ ansi.RED ++ ansi.BOLD, ansi.RESET });
            return error.invalid_responce;
        },
    }

    const body = response.written();

    if (body.len == 0 or body[0] != '[') {
        std.debug.print("{s}A non json responce was recieved which is most likely an error, responce recieved:\n{s}", .{ ansi.RED ++ ansi.BOLD, ansi.RESET });
        std.debug.print("{s}\n", .{body});
        return error.invalid_responce;
    }

    const json_handler: std.json.Parsed(std.json.Value) = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer json_handler.deinit();

    var list: std.ArrayList([]const u8) = .empty;

    const branches = json_handler.value.array.items;

    if (branches.len != 0) {
        for (branches) |single_branch| {
            const branch_name = single_branch.object.get("name").?.string;
            const duplicated_tag_string = try allocator.dupe(u8, branch_name);
            try list.append(allocator, duplicated_tag_string);
        }
    }

    return try list.toOwnedSlice(allocator);
}

pub fn url_to_repo_format(url_link: []const u8, allocator: std.mem.Allocator) !types.repository {
    if (!std.mem.startsWith(u8, url_link, "https://")) {
        return error.invalid_url;
    }
    const new_url_link = url_link[8..];
    if (!std.mem.startsWith(u8, new_url_link, "github.com/")) {
        return error.invalid_url;
    } else {
        // I will be implementing CodeBerg and GitLab
        display.err.unknown_provider();
    }

    const remaining_url_link = url_link[11..];

    var iter = std.mem.splitScalar(u8, remaining_url_link, '/');
    const owner_name = iter.next().?;
    var repo_name = iter.next().?;
    // https://github.com/zigistry/zigistry.git
    // the .git part
    if (std.mem.indexOf(u8, repo_name, ".")) |if_there_is_dot_index| {
        repo_name = repo_name[0 .. if_there_is_dot_index - 1];
    }
    const full_name = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ owner_name, repo_name });

    return .{
        .full_name = full_name,
        .owner = owner_name,
        .name = repo_name,
        .provider = .GitHub,
    };
}

pub fn query_to_repo(query: []const u8) anyerror!types.repository {
    var iterator = std.mem.splitScalar(u8, query, '/');
    const provider = iterator.next() orelse return error.wrong_format;
    const repo_full_name = iterator.rest();
    const owner = iterator.next() orelse return error.wrong_format;
    const repo_name = iterator.next() orelse return error.wrong_format;
    const unnesecary_next = iterator.next();
    if (unnesecary_next) |_| {
        return error.wrong_format;
    }

    if (std.mem.eql(u8, provider, "gh")) {
        return .{ .owner = owner, .provider = .GitHub, .full_name = repo_full_name, .name = repo_name };
    } else if (std.mem.eql(u8, provider, "cb")) {
        return .{ .owner = owner, .provider = .CodeBerg, .full_name = repo_full_name, .name = repo_name };
    } else if (std.mem.eql(u8, provider, "gl")) {
        return .{ .owner = owner, .provider = .GitLab, .full_name = repo_full_name, .name = repo_name };
    } else {
        return error.unknown_provider;
    }
}

pub fn fetch_info_from_github(repo: types.repository, allocator: std.mem.Allocator) !struct { license: []const u8, description: []const u8, topics: std.ArrayList([]const u8) } {
    switch (repo.provider) {
        .GitHub => {},
        else => {
            @panic("Other providers are comming soon");
        },
    }

    const fetch_url = try allocator.dupeZ(u8, try std.fmt.allocPrint(allocator, "https://api.github.com/repos/{s}", .{repo.full_name}));
    defer allocator.free(fetch_url);

    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    var response: std.Io.Writer.Allocating = .init(allocator);
    defer response.deinit();

    const result = try client.fetch(.{
        .location = .{ .url = fetch_url },
        .response_writer = &response.writer,
    });

    switch (result.status) {
        .ok => {},
        .not_found => {
            std.debug.print("{s}Error: {s}\"{s}\"{s} is not a repo.\n", .{ ansi.RED ++ ansi.BOLD, ansi.BRIGHT_CYAN, repo.full_name, ansi.RESET });
            return error.invalid_responce;
        },
        else => {
            std.debug.print("{s}Didn't recieve a responce, please check your internet connection.{s}", .{ ansi.RED ++ ansi.BOLD, ansi.RESET });
            return error.invalid_responce;
        },
    }

    const body = response.written();

    if (body.len == 0 or body[0] != '{') {
        std.debug.print("{s}A non json responce was recieved which is most likely an error, responce recieved:\n{s}", .{ ansi.RED ++ ansi.BOLD, ansi.RESET });
        std.debug.print("{s}\n", .{body});
        return error.invalid_responce;
    }

    var json_parsed: std.json.Parsed(std.json.Value) = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer json_parsed.deinit();
    const license = json_parsed.value.object.get("license").?.object.get("key").?.string;
    const description = if (json_parsed.value.object.get("description").? == .null)
        "No Description"
    else
        json_parsed.value.object.get("description").?.string;

    const topics = json_parsed.value.object.get("topics").?.array;

    var array_list: std.ArrayList([]const u8) = .empty;

    for (topics.items) |topic| {
        try array_list.append(allocator, try allocator.dupe(u8, topic.string));
    }

    return .{
        .license = try allocator.dupe(u8, license),
        .description = try allocator.dupe(u8, description),
        .topics = array_list,
    };
}

// https://ziggit.dev/t/how-to-parse-zon-like-json-during-runtime/12688/3

pub fn parse_build_zig_zon(allocator: std.mem.Allocator, content: [:0]const u8) !types.build_zig_zon {
    var ast = try std.zig.Ast.parse(allocator, content, .zon);
    defer ast.deinit(allocator);
    var zoir = try std.zig.ZonGen.generate(allocator, ast, .{ .parse_str_lits = true });
    defer zoir.deinit(allocator);

    const root = std.zig.Zoir.Node.Index.root.get(zoir);
    const root_struct = if (root == .struct_literal) root.struct_literal else return error.Parse;

    var result: types.build_zig_zon = .{};

    for (root_struct.names, 0..root_struct.vals.len) |name_node, index| {
        const value = root_struct.vals.at(@intCast(index));
        const name = name_node.get(zoir);

        if (std.mem.eql(u8, name, "name")) {
            result.name = try allocator.dupe(u8, value.get(zoir).enum_literal.get(zoir));
        }

        if (std.mem.eql(u8, name, "version")) {
            result.version = try allocator.dupe(u8, value.get(zoir).string_literal);
        }

        if (std.mem.eql(u8, name, "dependencies")) dep: {
            switch (value.get(zoir)) {
                .struct_literal => |sl| {
                    for (sl.names, 0..sl.vals.len) |dep_name, dep_index| {
                        const node = sl.vals.at(@intCast(dep_index));
                        const dep_body = try std.zon.parse.fromZoirNode(types.build_zig_zon.Dependency, allocator, ast, zoir, node, null, .{});

                        try result.dependencies.put(allocator, try allocator.dupe(u8, dep_name.get(zoir)), dep_body);
                    }
                },
                .empty_literal => {
                    break :dep;
                },
                else => return error.Parse,
            }
        }
    }

    return result;
}

pub fn parse_zigp_zon(allocator: std.mem.Allocator, content: [:0]const u8) !types.zigp_zon {
    var ast = try std.zig.Ast.parse(allocator, content, .zon);
    defer ast.deinit(allocator);
    var zoir = try std.zig.ZonGen.generate(allocator, ast, .{ .parse_str_lits = true });
    defer zoir.deinit(allocator);

    const root = std.zig.Zoir.Node.Index.root.get(zoir);
    const root_struct = if (root == .struct_literal) root.struct_literal else return error.Parse;

    var result: types.zigp_zon = .{};

    for (root_struct.names, 0..root_struct.vals.len) |name_node, index| {
        const value = root_struct.vals.at(@intCast(index));
        const name = name_node.get(zoir);

        if (std.mem.eql(u8, name, "zigp_version")) {
            result.zigp_version = try allocator.dupe(u8, value.get(zoir).string_literal);
        }

        if (std.mem.eql(u8, name, "zig_version")) {
            result.zig_version = try allocator.dupe(u8, value.get(zoir).string_literal);
        }

        if (std.mem.eql(u8, name, "last_updated")) {
            result.last_updated = try allocator.dupe(u8, value.get(zoir).string_literal);
        }

        if (std.mem.eql(u8, name, "dependencies")) dep: {
            switch (value.get(zoir)) {
                .struct_literal => |sl| {
                    for (sl.names, 0..sl.vals.len) |dep_name, dep_index| {
                        const node = sl.vals.at(@intCast(dep_index));
                        const dep_body = try std.zon.parse.fromZoirNode(types.zigp_zon.Dependency, allocator, ast, zoir, node, null, .{});

                        try result.dependencies.put(allocator, try allocator.dupe(u8, dep_name.get(zoir)), dep_body);
                    }
                },
                .empty_literal => {
                    break :dep;
                },
                else => return error.Parse,
            }
        }
    }

    return result;
}

pub fn range_input_taker(
    lower_range_inclusive: usize,
    upper_range_inclusive: usize,
) usize {
    while (true) {
        std.debug.print("{s}>>>{s} ", .{ ansi.BRIGHT_CYAN, ansi.RESET });

        const user_select_number = read_integer() catch {
            std.debug.print("{s}Invalid input recieved.{s}", .{ ansi.BRIGHT_RED, ansi.RESET });
            continue;
        };

        if (user_select_number < lower_range_inclusive or user_select_number > upper_range_inclusive) {
            std.debug.print("{s}Error:{s} Number selection is out of range.\n", .{ ansi.RED ++ ansi.BOLD, ansi.RESET });
            continue;
        }

        return user_select_number;
    }
}
