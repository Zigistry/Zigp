const std = @import("std");

const Providers = enum { GitHub, CodeBerg, GitLab };

pub const semver = struct {
    major: u32,
    minor: u32,
    patch: u32,
    remaining: []const u8,
};

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
    fingerprint: ?u64 = null,
    dependencies: std.StringArrayHashMapUnmanaged(Dependency) = .empty,
    minimum_zig_version: ?[]const u8 = null,
    paths: ?[][]const u8 = null,

    pub const Dependency = struct {
        url: ?[]const u8 = null,
        hash: ?[]const u8 = null,
        path: ?[]const u8 = null,
        lazy: ?bool = null,
    };
};

pub fn build_zig_zon_to_string(data: build_zig_zon, allocator: std.mem.Allocator) ![]const u8 {
    var result: std.array_list.Aligned(u8, null) = .empty;
    try result.appendSlice(allocator, ".{\n");
    if (data.version) |build_zig_zon_version| {
        try result.appendSlice(allocator, "    .version = \"");
        try result.appendSlice(allocator, build_zig_zon_version);
        try result.append(allocator, '"');
        try result.append(allocator, ',');
        try result.append(allocator, '\n');
    }
    if (data.minimum_zig_version) |minversion| {
        try result.appendSlice(allocator, "    .minimum_zig_version = \"");
        try result.appendSlice(allocator, minversion);
        try result.append(allocator, '"');
        try result.append(allocator, ',');
        try result.append(allocator, '\n');
    }
    if (data.paths) |path_list| {
        try result.appendSlice(allocator, "    .paths = .{\n");
        for (path_list) |path| {
            try result.appendSlice(allocator, "        \"");
            try result.appendSlice(allocator, path);
            try result.append(allocator, '"');
            try result.append(allocator, ',');
            try result.append(allocator, '\n');
        }
        try result.appendSlice(allocator, "    },");

        try result.append(allocator, '\n');
    }

    if (data.name) |name| {
        try result.appendSlice(allocator, "    .name = .");
        try result.appendSlice(allocator, name);
        try result.append(allocator, ',');
        try result.append(allocator, '\n');
    }
    if (data.fingerprint) |fingerprint| {
        try result.appendSlice(allocator, "    .fingerprint = ");
        try result.appendSlice(allocator, try std.fmt.allocPrint(allocator, "0x{X:0>16}", .{fingerprint}));
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

        if (dependency.value_ptr.url) |dependencyurl| {
            try result.appendSlice(allocator, "            .url = \"");
            try result.appendSlice(allocator, dependencyurl);
            try result.appendSlice(allocator, "\",\n");
        }

        if (dependency.value_ptr.hash) |dependencyhash| {
            try result.appendSlice(allocator, "            .hash = \"");
            try result.appendSlice(allocator, dependencyhash);
            try result.appendSlice(allocator, "\",\n");
        }

        if (dependency.value_ptr.path) |dependencypath| {
            try result.appendSlice(allocator, "            .path = \"");
            try result.appendSlice(allocator, dependencypath);
            try result.appendSlice(allocator, "\",\n");
        }

        if (dependency.value_ptr.lazy) |dependencylazy| {
            try result.appendSlice(allocator, "            .lazy = \"");
            try result.appendSlice(allocator, if (dependencylazy) "true" else "false");
            try result.appendSlice(allocator, "\",\n");
        }
        try result.appendSlice(allocator, "        },\n");
    }
    try result.appendSlice(allocator, "    },\n");

    try result.appendSlice(allocator, "}\n");

    return try result.toOwnedSlice(allocator);
}

pub fn semver_to_string(input_semver: semver, allocator: std.mem.Allocator) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "{}.{}.{}", .{ input_semver.major, input_semver.minor, input_semver.patch });
}

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

pub const update = enum {
    caret_range,
    tilde_range,
    not_following_semver_name_exact_versioning,
    exact_versioning,
    any_latest,
    latest_branching,
    exact_branching,
    range_based_versioning,
};
