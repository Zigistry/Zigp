const std = @import("std");

const Providers = enum { GitHub, CodeBerg, GitLab };

pub const repository = struct {
    provider: Providers,
    owner: []const u8,
    name: []const u8,
    full_name: []const u8,
};

pub const zigp_zon = struct {
    zigp_version: ?[]const u8 = null,
    zig_version: ?[]const u8 = null,
    last_updated: ?[]const u8 = null,
    dependencies: std.StringArrayHashMapUnmanaged(Dependency) = .empty,
    pub const Dependency = struct {
        owner_name: ?[]const u8 = null,
        repo_name: ?[]const u8 = null,
        provider: Providers,
        version: ?[]const u8,
    };
};

pub const build_zig_zon = struct {
    name: ?[]const u8 = null,
    version: ?[]const u8 = null,
    dependencies: std.StringArrayHashMapUnmanaged(Dependency) = .empty,

    pub const Dependency = struct {
        url: ?[]const u8 = null,
        hash: ?[]const u8 = null,
        path: ?[]const u8 = null,
        lazy: ?bool = null,
    };
};

pub fn zigp_zon_to_string(data: zigp_zon, allocator: std.mem.Allocator) ![]const u8 {
    var result: std.array_list.Aligned(u8, null) = .empty;
    try result.appendSlice(allocator, ".{\n");

    if (data.zigp_version) |zigp_ver| {
        try result.appendSlice(allocator, "    .zigp_version = \"");
        try result.appendSlice(allocator, zigp_ver);
        try result.append(allocator, '"');
        try result.append(allocator, ',');
        try result.append(allocator, '\n');
    }

    if (data.zig_version) |zig_version| {
        try result.appendSlice(allocator, "    .zig_version = \"");
        try result.appendSlice(allocator, zig_version);
        try result.append(allocator, '"');
        try result.append(allocator, ',');
        try result.append(allocator, '\n');
    }

    if (data.last_updated) |_| {
        try result.appendSlice(allocator, "    .timestamp = \"");
        // const asdf = try std.time.Instant.now();
        // try result.appendSlice(
        //     allocator,
        // );
        try result.append(allocator, '"');
        try result.append(allocator, ',');
        try result.append(allocator, '\n');
    }

    var iter = data.dependencies.iterator();

    try result.appendSlice(allocator, "    .dependencies = .{\n");
    while (iter.next()) |dependency| {
        const key = dependency.key_ptr.*;
        try result.appendSlice(allocator, "        .");
        try result.appendSlice(allocator, key);
        try result.appendSlice(allocator, " = .{\n");

        try result.appendSlice(allocator, "            .owner_name = \"");
        try result.appendSlice(allocator, dependency.value_ptr.owner_name.?);
        try result.appendSlice(allocator, "\",\n");

        try result.appendSlice(allocator, "            .repo_name = \"");
        try result.appendSlice(allocator, dependency.value_ptr.repo_name.?);
        try result.appendSlice(allocator, "\",\n");

        try result.appendSlice(allocator, "            .provider = ");
        switch (dependency.value_ptr.provider) {
            .GitHub => try result.appendSlice(allocator, ".GitHub"),
            .CodeBerg => try result.appendSlice(allocator, ".CodeBerg"),
            .GitLab => try result.appendSlice(allocator, ".GitLab"),
        }
        try result.appendSlice(allocator, ",\n");

        try result.appendSlice(allocator, "            .version = \"");
        try result.appendSlice(allocator, dependency.value_ptr.version.?);
        try result.appendSlice(allocator, "\",\n");
        try result.appendSlice(allocator, "        },\n");
    }
    try result.appendSlice(allocator, "    },\n");
    try result.appendSlice(allocator, "}\n");

    return try result.toOwnedSlice(allocator);
}
