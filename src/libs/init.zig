const std = @import("std");
const ansi = @import("./ansi_codes.zig");
const hfs = @import("./helper_functions.zig");

const content =
    \\.{
    \\    .zigp_version = "0.0.0",
    \\    .zig_version = "0.15.1",
    \\    .dependencies = .{},
    \\}
;

pub fn init() !void {
    if (hfs.file_exists("zigp.zon")) {
        std.debug.print("{s}zigp.zon{s} already exists.\n", .{ ansi.BRIGHT_YELLOW ++ ansi.UNDERLINE, ansi.RESET });
    } else {
        const file = try std.fs.cwd().createFile("./zigp.zon", .{});
        defer file.close();
        try file.writeAll(content);
        std.debug.print("{s}Empty zig file has been created.{s}\n", .{ ansi.BRIGHT_GREEN, ansi.RESET });
    }
}
