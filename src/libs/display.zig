const std = @import("std");
const ansi = @import("./ansi_codes.zig");

pub const help = struct {
    pub fn all_info() void {
        std.debug.print("{s}╔══════════════════════════════════════════╗\n", .{ansi.BRIGHT_CYAN});
        std.debug.print("║         Welcome to Zigistry-CLI!         ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════╝{s}\n\n", .{ansi.RESET});

        std.debug.print("{s}Here are some commands you can use:{s}\n", .{ ansi.BRIGHT_YELLOW, ansi.RESET });
        std.debug.print("{s}--------------------------------------------------------{s}\n", .{ ansi.BRIGHT_WHITE, ansi.RESET });

        std.debug.print("{s}add{s}      - Add a Zig package to your zig project.\n", .{ ansi.BRIGHT_GREEN, ansi.RESET });
        std.debug.print("    Example: {s}zigp{s} add {s}gh/capy-ui/capy{s}\n", .{ ansi.BRIGHT_MAGENTA, ansi.BRIGHT_WHITE, ansi.BRIGHT_MAGENTA, ansi.RESET });
        std.debug.print("{s}--------------------------------------------------------{s}\n", .{ ansi.BRIGHT_WHITE, ansi.RESET });

        std.debug.print("{s}install{s}      - Install a zig program (i.e application).\n", .{ ansi.BRIGHT_GREEN, ansi.RESET });
        std.debug.print("    Example: {s}zigp{s} install {s}gh/zigtools/zls{s}\n", .{ ansi.BRIGHT_MAGENTA, ansi.BRIGHT_WHITE, ansi.BRIGHT_MAGENTA, ansi.RESET });
        std.debug.print("{s}--------------------------------------------------------{s}\n", .{ ansi.BRIGHT_WHITE, ansi.RESET });

        std.debug.print("{s}update{s}      - Update all dependencies of a zig project.\n", .{ ansi.BRIGHT_GREEN, ansi.RESET });
        std.debug.print("    Example: {s}zigp{s} update {s}all{s}\n", .{ ansi.BRIGHT_MAGENTA, ansi.BRIGHT_WHITE, ansi.BRIGHT_MAGENTA, ansi.RESET });
        std.debug.print("{s}--------------------------------------------------------{s}\n", .{ ansi.BRIGHT_WHITE, ansi.RESET });

        std.debug.print("{s}info{s}      - Display the info of a repository.\n", .{ ansi.BRIGHT_GREEN, ansi.RESET });
        std.debug.print("    Example: {s}zigp{s} info {s}gh/zigtools/zls{s}\n", .{ ansi.BRIGHT_MAGENTA, ansi.BRIGHT_WHITE, ansi.BRIGHT_MAGENTA, ansi.RESET });
        std.debug.print("{s}--------------------------------------------------------{s}\n", .{ ansi.BRIGHT_WHITE, ansi.RESET });

        std.debug.print("{s}version{s}      - Display the version of zigp.\n", .{ ansi.BRIGHT_GREEN, ansi.RESET });
        std.debug.print("{s}--------------------------------------------------------{s}\n", .{ ansi.BRIGHT_WHITE, ansi.RESET });

        std.debug.print("{s}self-update{s}  - Update zigp itself to the latest version.\n", .{ ansi.BRIGHT_GREEN, ansi.RESET });
        std.debug.print("{s}--------------------------------------------------------{s}\n\n", .{ ansi.BRIGHT_WHITE, ansi.RESET });

        std.debug.print("{s}♥{s} Made with {s}Love{s} by {s}https://zigistry.dev{s} {s}♥{s}\n\n", .{ ansi.BRIGHT_MAGENTA, ansi.RESET, ansi.BRIGHT_YELLOW, ansi.RESET, ansi.BRIGHT_CYAN, ansi.RESET, ansi.BRIGHT_MAGENTA, ansi.RESET });
    }

    pub fn add_info() void {
        std.debug.print("{s}╔════════════════════════════════════════════╗\n", .{ansi.BRIGHT_CYAN});
        std.debug.print("║        Zigistry Add Package Command        ║\n", .{});
        std.debug.print("╚════════════════════════════════════════════╝{s}\n\n", .{ansi.RESET});

        std.debug.print("{s}Description:{s}\n", .{ ansi.BRIGHT_YELLOW, ansi.RESET });
        std.debug.print("    The add command is used to add a package into your Zig project.\n\n", .{});

        std.debug.print("{s}Syntax:{s}\n", .{ ansi.BRIGHT_YELLOW, ansi.RESET });
        std.debug.print("    {s}zigp{s} add {s}<provider-name>/<package-name>{s}\n\n", .{ ansi.BRIGHT_MAGENTA, ansi.BRIGHT_GREEN, ansi.BRIGHT_MAGENTA, ansi.RESET });

        std.debug.print("{s}Example:{s}\n", .{ ansi.BRIGHT_YELLOW, ansi.RESET });
        std.debug.print("    {s}zigp{s} add {s}gh/capy-ui/capy{s}\n\n", .{ ansi.BRIGHT_MAGENTA, ansi.BRIGHT_GREEN, ansi.BRIGHT_MAGENTA, ansi.RESET });
        std.debug.print("{s}The above command adds the 'capy' package from GitHub(gh).{s}\n\n", .{ ansi.BRIGHT_WHITE ++ ansi.BOLD, ansi.RESET });
    }

    pub fn update_info() void {
        std.debug.print("{s}╔════════════════════════════════════════════╗\n", .{ansi.BRIGHT_CYAN});
        std.debug.print("║      Zigistry Update Package Command       ║\n", .{});
        std.debug.print("╚════════════════════════════════════════════╝{s}\n\n", .{ansi.RESET});

        std.debug.print("{s}Description:{s}\n", .{ ansi.BRIGHT_YELLOW, ansi.RESET });
        std.debug.print("    The update command is used to update all packages of your Zig project.\n\n", .{});

        std.debug.print("{s}Syntax:{s}\n", .{ ansi.BRIGHT_YELLOW, ansi.RESET });
        std.debug.print("    {s}zigp{s} update {s}all{s}\n\n", .{ ansi.BRIGHT_MAGENTA, ansi.BRIGHT_GREEN, ansi.BRIGHT_MAGENTA, ansi.RESET });
    }

    pub fn install_info() void {
        std.debug.print("{s}╔════════════════════════════════════════════╗\n", .{ansi.BRIGHT_CYAN});
        std.debug.print("║      Zigistry Install Program Command      ║\n", .{});
        std.debug.print("╚════════════════════════════════════════════╝{s}\n\n", .{ansi.RESET});
        std.debug.print("{s}Comming Soon!{s}\n\n", .{ ansi.BOLD ++ ansi.GREEN ++ ansi.UNDERLINE, ansi.RESET });
        std.debug.print("{s}Description:{s}\n", .{ ansi.BRIGHT_YELLOW, ansi.RESET });
        std.debug.print("    The install command is used to install an executable.\n\n", .{});

        std.debug.print("{s}Syntax:{s}\n", .{ ansi.BRIGHT_YELLOW, ansi.RESET });
        std.debug.print("    {s}zigp{s} install {s}<provider-name>/<owner-name>/<repo-name>{s}\n\n", .{ ansi.BRIGHT_MAGENTA, ansi.BRIGHT_GREEN, ansi.BRIGHT_MAGENTA, ansi.RESET });

        std.debug.print("{s}Example:{s}\n", .{ ansi.BRIGHT_YELLOW, ansi.RESET });
        std.debug.print("    {s}zigp{s} install {s}gh/zigtools/zls{s}\n\n", .{ ansi.BRIGHT_MAGENTA, ansi.BRIGHT_GREEN, ansi.BRIGHT_MAGENTA, ansi.RESET });
        std.debug.print("{s}The above command installs 'zls' from GitHub(gh) on your system and exports it to your $PATH.{s}\n\n", .{ ansi.BRIGHT_WHITE ++ ansi.BOLD, ansi.RESET });
    }
};

pub const err = struct {
    pub fn wrong_repo_format(x: []const u8) void {
        std.debug.print("{s}{s}You have entered repository format in a wrong way.\n", .{ ansi.RED, ansi.BOLD });
        std.debug.print("\nWrong format: \n", .{});
        std.debug.print("            \"{s}\"{s}\n", .{ x, ansi.RESET });

        std.debug.print("{s}Correct format: {s}\n", .{ ansi.BRIGHT_CYAN ++ ansi.BOLD, ansi.RESET });

        std.debug.print("    {s}zigp{s} install/add/info {s}<provider-name>/<owner-name>/<repo-name>{s}\n\n", .{ ansi.BRIGHT_MAGENTA, ansi.BRIGHT_GREEN, ansi.BRIGHT_MAGENTA, ansi.RESET });

        std.debug.print("{s}Example:{s}\n", .{ ansi.BRIGHT_YELLOW ++ ansi.BOLD, ansi.RESET });
        std.debug.print("{s}To add a package:{s}\n", .{ ansi.WHITE ++ ansi.BOLD, ansi.RESET });
        std.debug.print("    {s}zigp{s} add {s}gh/capy-ui/capy{s}\n", .{ ansi.BRIGHT_MAGENTA, ansi.BRIGHT_GREEN, ansi.BRIGHT_MAGENTA, ansi.RESET });
        std.debug.print("{s}To install an application:{s}\n", .{ ansi.WHITE ++ ansi.BOLD, ansi.RESET });
        std.debug.print("    {s}zigp{s} install {s}gh/zigtools/zls{s}\n\n", .{ ansi.BRIGHT_MAGENTA, ansi.BRIGHT_GREEN, ansi.BRIGHT_MAGENTA, ansi.RESET });
        std.debug.print("{s}To get info of a repository:{s}\n", .{ ansi.WHITE ++ ansi.BOLD, ansi.RESET });
        std.debug.print("    {s}zigp{s} info {s}gh/zigtools/zls{s}\n\n", .{ ansi.BRIGHT_MAGENTA, ansi.BRIGHT_GREEN, ansi.BRIGHT_MAGENTA, ansi.RESET });
    }
    pub fn unknown_argument(x: []const u8) void {
        std.debug.print("{s}{s}Unknown argument recieved: {s}{s}\n", .{ ansi.RED, ansi.BOLD, x, ansi.RESET });
        help.all_info();
    }
    pub fn failed_self_update() void {
        std.debug.print("{s}{s}Zigp wasn't able to update itself. Some error occured in the build script.{s}\n", .{ ansi.RED, ansi.BOLD, ansi.RESET });
    }
    pub fn unexpected_failed_self_update(x: u8) void {
        std.debug.print("{s}Zigp wasn't able to update itself due to an unknown or unexpected issue. Value returned: {}{s}\n", .{ ansi.BRIGHT_RED, x, ansi.RESET });
    }
    pub fn unknown_provider() void {
        std.debug.print("{s}{s}Unknown provider recieved!{s}\n", .{ ansi.RED, ansi.BOLD, ansi.RESET });
        std.debug.print("{s}Tip: Zigp currently support only GitHub (gh) as a provider, other providers are comming soon.{s}\n", .{ ansi.BRIGHT_YELLOW ++ ansi.BOLD, ansi.RESET });
        help.add_info();
    }
};

pub const success = struct {
    pub fn completed_self_update() void {
        std.debug.print("{s}Zigp has successfully updated itself.{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, ansi.RESET });
    }
};
