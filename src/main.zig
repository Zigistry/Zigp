const std = @import("std");
const display = @import("libs/display.zig");
const add_package = @import("./packages/add.zig");
const update_package = @import("./packages/update.zig");
const remove_package = @import("./packages/remove.zig");
const info_package = @import("./packages/info.zig");
const program_manager = @import("./programs/install.zig");
const types = @import("types.zig");
const hfs = @import("./libs/helper_functions.zig");
const init = @import("./libs/init.zig");
const package_search = @import("./packages/search.zig");

inline fn eql(x: []const u8, y: []const u8) bool {
    return std.mem.eql(u8, x, y);
}

fn self_update(allocator: std.mem.Allocator) !void {
    const update_command_result = try hfs.run_cli_command(&.{
        "sh",
        "-c",
        "curl https://raw.githubusercontent.com/zigistry/zigp/main/install_script.sh -sSf | sh",
    }, allocator, .no_read);
    switch (update_command_result.Exited) {
        0 => display.success.completed_self_update(),
        1 => display.err.failed_self_update(),
        else => display.err.unexpected_failed_self_update(update_command_result.Exited),
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

    hfs.set_file_stdin();
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
        } else if (eql(args[1], "init")) {
            try init.init();
        } else if (eql(args[1], "install")) {
            display.help.install_info();
        } else if (eql(args[1], "update")) {
            display.help.update_info();
        } else if (eql(args[1], "remove")) {
            display.help.remove_info();
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
            try program_manager.install_app(repo, allocator);
        } else if (eql(args[1], "search")) {
            const query = if (args.len > 2) args[2] else null;
            const filter = if (args.len > 3) args[3] else null;
            try package_search.search_packages(allocator, query, filter);
        } else if (eql(args[1], "remove")) {
            try remove_package.remove_dependency(allocator, args[2]);
        } else if (eql(args[1], "update")) {
            if (eql(args[2], "all")) {
                try update_package.update_packages(allocator);
            } else if (eql(args[2], "--specific")) {
                display.help.update_info();
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
            try add_package.add_package(repo, allocator);
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
            try info_package.info(repo, allocator);
        } else if (eql(args[1], "search")) {
            const query = if (args.len > 2) args[2] else null;
            const filter = if (args.len > 3) args[3] else null;
            try package_search.search_packages(allocator, query, filter);
        } else display.err.unknown_argument(args[2]),
        // args[0]  args[1]     args[2]         args[3]
        // zigp     something   something_else  yet_something
        else => display.err.unknown_argument(args[2]),
        4 => if (eql(args[1], "update")) {
            if (eql(args[2], "--specific")) {
                try update_package.update_specific_packages(args[3], allocator);
            }
        },
    }
}
// zigp update all
// zigp update --specific thing
