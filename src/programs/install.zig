const std = @import("std");
const display = @import("../libs/display.zig");
const types = @import("../types.zig");
const hfs = @import("../libs/helper_functions.zig");
const ansi = @import("../libs/ansi_codes.zig");

pub fn install_app(repo: types.repository, allocator: std.mem.Allocator) !void {
    std.debug.print("You are about to install a program, do you trust {s}? (Y/n): ", .{repo.full_name});
    if (!hfs.yes_no_input_taker()) return;

    const items = hfs.fetch_versions(repo, allocator) catch return;

    defer for (items) |item| {
        allocator.free(item);
    };

    std.debug.print("{s}Installing {s}{s}{s}\n", .{ ansi.YELLOW, ansi.UNDERLINE, repo.full_name, ansi.RESET });
    std.debug.print("{s}Please select the version you want to install (type the index number):{s}\n", .{ ansi.BRIGHT_CYAN ++ ansi.BOLD, ansi.RESET });

    for (items, 1..) |value, i| {
        std.debug.print("{}){s} {s}{s}\n", .{ i, ansi.BOLD, value, ansi.RESET });
    }

    while (true) {
        const number = hfs.range_input_taker(1, items.len);
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
            const process = try hfs.run_cli_command(&.{ "sh", "-c", sh }, allocator, .no_read);
            switch (process.Exited) {
                0 => {},
                1 => {
                    std.debug.print("{s}Zig fetch returned an error. The process returned 1 exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, ansi.RESET });
                    return;
                },
                else => {
                    std.debug.print("{s}Zig fetch returned an unknown error. It returned {} exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, process.Exited, ansi.RESET });
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
            const process = try hfs.run_cli_command(&.{ "sh", "-c", sh }, allocator, .no_read);
            switch (process.Exited) {
                0 => {},
                1 => {
                    std.debug.print("{s}Zig fetch returned an error. The process returned 1 exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, ansi.RESET });
                    return;
                },
                else => {
                    std.debug.print("{s}Zig fetch returned an unknown error. It returned {} exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, process.Exited, ansi.RESET });
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

        const process = try hfs.run_cli_command(&.{ "sh", "-c", path_export }, allocator, .no_read);

        switch (process.Exited) {
            0 => std.debug.print("{s}Installed {s}{s}{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, ansi.RESET ++ ansi.BRIGHT_YELLOW ++ ansi.UNDERLINE, repo.full_name, ansi.RESET }),
            else => std.debug.print("Error while exporting app to PATH.", .{}),
        }
        break;
    }
}
