const std = @import("std");
const display = @import("libs/display.zig");
const package_manager = @import("package_manager.zig");
const types = @import("types.zig");
const hfs = @import("./libs/helper_functions.zig");

inline fn eql(x: []const u8, y: []const u8) bool {
    return std.mem.eql(u8, x, y);
}

fn self_update(allocator: std.mem.Allocator) !void {
    var process = std.process.Child.init(&[_][]const u8{
        "sh",
        "-c",
        "curl https://raw.githubusercontent.com/zigistry/zigp/main/install_script.sh -sSf | sh",
    }, allocator);

    const result = try process.spawnAndWait();
    switch (result.Exited) {
        0 => display.success.completed_self_update(),
        1 => display.err.failed_self_update(),
        else => display.err.unexpected_failed_self_update(result.Exited),
    }
}

pub fn main() !void {
    // allocator
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = std.heap.c_allocator;
    // defer {
    //     const deinit_status = gpa.deinit();
    //     if (deinit_status == .leak) @panic("Memory got leaked.");
    // }

    const allocator = std.heap.c_allocator;

    // arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // parse
    switch (args.len) {

        // zigp
        1 => display.help.all_info(),

        // args[0]  args[1]
        // zigp     something
        2 => if (eql(args[1], "add")) {
            display.help.add_info();
        } else if (eql(args[1], "install")) {
            display.help.install_info();
        } else if (eql(args[1], "help")) {
            display.help.all_info();
        } else if (eql(args[1], "self-update")) {
            try self_update(allocator);
        } else if (eql(args[1], "version")) {
            std.debug.print("v0.0.0\n", .{});
        } else display.err.unknown_argument(args[1]),

        // args[0]  args[1]     args[2]
        // zigp     something   something_else
        3 => if (eql(args[1], "install")) {
            const repo = hfs.query_to_repo(args[2]) catch |err| switch (err) {
                error.unknown_provider => {
                    display.err.unknown_provider();
                    return;
                },
                error.wrong_format => {
                    display.err.wrong_repo_format(args[2]);
                    return;
                },
                else => {
                    display.err.unknown_argument(args[2]);
                    return;
                },
            };
            // ======= I will soon be adding more providers =======
            if (repo.provider != .GitHub) {
                display.err.unknown_provider();
                return;
            }
            // ====================================================
            try package_manager.install_app(repo, allocator);
        } else if (eql(args[1], "update")) {
            if (eql(args[2], "all")) {
                try package_manager.update_packages(allocator);
            }
        } else if (eql(args[1], "add")) {
            const repo = hfs.query_to_repo(args[2]) catch |err| switch (err) {
                error.unknown_provider => {
                    display.err.unknown_provider();
                    return;
                },
                error.wrong_format => {
                    display.err.wrong_repo_format(args[2]);
                    return;
                },
                else => {
                    display.err.unknown_argument(args[2]);
                    return;
                },
            };
            // ======= I will soon be adding more providers =======
            if (repo.provider != .GitHub) {
                display.err.unknown_provider();
                return;
            }
            // ====================================================
            try package_manager.add_package(repo, allocator);
        } else if (eql(args[1], "info")) {
            const repo = hfs.query_to_repo(args[2]) catch |err| switch (err) {
                error.unknown_provider => {
                    display.err.unknown_provider();
                    return;
                },
                error.wrong_format => {
                    display.err.wrong_repo_format(args[2]);
                    return;
                },
                else => {
                    display.err.unknown_argument(args[2]);
                    return;
                },
            };

            if (repo.provider != .GitHub) {
                display.err.unknown_provider();
                return;
            }
            try package_manager.info(repo, allocator);
        } else display.err.unknown_argument(args[2]),

        // args[0]  args[1]     args[2]         args[3]
        // zigp     something   something_else  yet_something
        else => display.err.unknown_argument(args[2]),
    }
}
