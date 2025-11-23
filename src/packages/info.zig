const types = @import("../types.zig");
const std = @import("std");
const hfs = @import("../libs/helper_functions.zig");
const ansi = @import("ansi");

pub fn info(repo: types.repository, allocator: std.mem.Allocator) !void {
    const versions = try hfs.fetch_versions(repo, allocator);
    defer for (versions) |item| {
        allocator.free(item);
    };

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

    const version = switch (versions.len) {
        0 => "latest (unstable) no releases found.",
        else => versions[0],
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
    var package = false;
    var program = false;
    for (github_info.topics.items) |topic| {
        if (std.mem.eql(u8, topic, "zig-package")) {
            package = true;
        } else if (std.mem.eql(u8, topic, "zig")) {
            program = true;
        }
    }
    if (package) {
        std.debug.print("{s}zigistry.dev{s}: https://zigistry.dev/{s}/{s}/{s}{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, ansi.RESET, "packages", "github", repo.full_name, ansi.RESET });
    } else if (program) {
        std.debug.print("{s}zigistry.dev{s}: https://zigistry.dev/{s}/{s}/{s}{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, ansi.RESET, "programs", "github", repo.full_name, ansi.RESET });
    }
}
