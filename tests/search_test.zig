const std = @import("std");
const testing = std.testing;
const search = @import("search");
const http_mock = @import("http_mock.zig");

fn withCapturedOutput(
    client: *http_mock.MockHttpClient,
    comptime run: fn (*http_mock.MockHttpClient) anyerror!void,
) !struct { stdout: []const u8, stderr: []const u8 } {
    var out_buf: [8192]u8 = undefined;
    var err_buf: [4096]u8 = undefined;

    const out_fbs = std.io.fixedBufferStream(&out_buf);
    const err_fbs = std.io.fixedBufferStream(&err_buf);

    const stdout_file = std.fs.File.stdout();
    const stderr_file = std.fs.File.stderr();

    var stdout_writer_buf: [4096]u8 = undefined;
    var stderr_writer_buf: [4096]u8 = undefined;

    const old_stdout = stdout_file.writer(&stdout_writer_buf);
    const old_stderr = stderr_file.writer(&stderr_writer_buf);

    defer {
        _ = old_stdout;
        _ = old_stderr;
    }

    try run(client);

    return .{
        .stdout = out_fbs.getWritten(),
        .stderr = err_fbs.getWritten(),
    };
}

const TestContext = struct {
    allocator: std.mem.Allocator,
    mock_client: http_mock.MockHttpClient,

    fn init(allocator: std.mem.Allocator) !TestContext {
        return .{
            .allocator = allocator,
            .mock_client = http_mock.MockHttpClient.init(allocator),
        };
    }

    fn deinit(self: *TestContext) void {
        std.debug.print("Deinit called\n", .{});
        self.mock_client.deinit();
        std.debug.print("Deinit completed\n", .{});
    }
};

test "search_packages: valid query and filter" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();

    const mock_body_str =
        \\ [{"avatar_url":"https://avatars.githubusercontent.com/u/201527030?v=4","name":"MLX.zig","full_name":"jaco-bro/MLX.zig","created_at":"2025-03-14T14:47:09Z","description":"MLX.zig: Phi-4, Llama 3.2, and Whisper in Zig","default_branch":"main","open_issues":2,"stargazers_count":28,"forks_count":4,"watchers_count":28,"tags_url":"https://api.github.com/repos/jaco-bro/MLX.zig/tags","license":"Apache-2.0","topics":["llama","llm","mlx","pcre2","regex","tiktoken","zig","zig-package"],"size":5431,"fork":false,"updated_at":"2025-10-02T01:55:39Z","has_build_zig":true,"has_build_zig_zon":true,"zig_minimum_version":"unknown","repo_from":"github","dependencies":[{"name":"pcre2","url":"https://github.com/PCRE2Project/pcre2","commit":"refs","tar_url":"https://github.com/PCRE2Project/pcre2/archive/refs.tar.gz","type":"remote"}],"dependents":[]},{"avatar_url":"https://avatars.githubusercontent.com/u/201527030?v=4","name":"tokenizer","full_name":"jaco-bro/tokenizer","created_at":"2025-04-19T04:26:17Z","description":"BPE tokenizer for LLMs in Pure Zig","default_branch":"main","open_issues":0,"stargazers_count":5,"forks_count":3,"watchers_count":5,"tags_url":"https://api.github.com/repos/jaco-bro/tokenizer/tags","license":"Apache-2.0","topics":["bpe-tokenizer","pcre2","regex","tokenizer","zig","zig-package"],"size":305,"fork":false,"updated_at":"2025-09-10T20:08:12Z","has_build_zig":true,"has_build_zig_zon":true,"zig_minimum_version":"unknown","repo_from":"github","dependencies":[{"name":"pcre2","url":"https://github.com/PCRE2Project/pcre2","commit":"refs","tar_url":"https://github.com/PCRE2Project/pcre2/archive/refs.tar.gz","type":"remote"}],"dependents":["https://github.com/allyourcodebase/boost-libraries-zig"]}]
    ;

    const mock_body = try testing.allocator.dupe(u8, mock_body_str);
    defer testing.allocator.free(mock_body);

    try ctx.mock_client.expectRequest(
        "https://api.example.com/search?q=json&filter=http",
        .ok,
        mock_body,
    );

    _ = try withCapturedOutput(&ctx.mock_client, struct {
        fn run(client: *http_mock.MockHttpClient) !void {
            try search.search_packages_with_client(testing.allocator, client, "json", "http");
        }
    }.run);

    try testing.expectEqual(@as(usize, 1), ctx.mock_client.getRequests().len);
}

test "search_packages: filter only" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();

    const mock_body = try testing.allocator.dupe(u8,
        \\ [{"avatar_url":"https://avatars.githubusercontent.com/u/201527030?v=4","name":"MLX.zig","full_name":"jaco-bro/MLX.zig","created_at":"2025-03-14T14:47:09Z","description":"MLX.zig: Phi-4, Llama 3.2, and Whisper in Zig","default_branch":"main","open_issues":2,"stargazers_count":28,"forks_count":4,"watchers_count":28,"tags_url":"https://api.github.com/repos/jaco-bro/MLX.zig/tags","license":"Apache-2.0","topics":["llama","llm","mlx","pcre2","regex","tiktoken","zig","zig-package"],"size":5431,"fork":false,"updated_at":"2025-10-02T01:55:39Z","has_build_zig":true,"has_build_zig_zon":true,"zig_minimum_version":"unknown","repo_from":"github","dependencies":[{"name":"pcre2","url":"https://github.com/PCRE2Project/pcre2","commit":"refs","tar_url":"https://github.com/PCRE2Project/pcre2/archive/refs.tar.gz","type":"remote"}],"dependents":[]},{"avatar_url":"https://avatars.githubusercontent.com/u/201527030?v=4","name":"tokenizer","full_name":"jaco-bro/tokenizer","created_at":"2025-04-19T04:26:17Z","description":"BPE tokenizer for LLMs in Pure Zig","default_branch":"main","open_issues":0,"stargazers_count":5,"forks_count":3,"watchers_count":5,"tags_url":"https://api.github.com/repos/jaco-bro/tokenizer/tags","license":"Apache-2.0","topics":["bpe-tokenizer","pcre2","regex","tokenizer","zig","zig-package"],"size":305,"fork":false,"updated_at":"2025-09-10T20:08:12Z","has_build_zig":true,"has_build_zig_zon":true,"zig_minimum_version":"unknown","repo_from":"github","dependencies":[{"name":"pcre2","url":"https://github.com/PCRE2Project/pcre2","commit":"refs","tar_url":"https://github.com/PCRE2Project/pcre2/archive/refs.tar.gz","type":"remote"}],"dependents":["https://github.com/allyourcodebase/boost-libraries-zig"]}]
    );
    defer testing.allocator.free(mock_body);

    try ctx.mock_client.expectRequest("https://api.example.com/search?filter=http", .ok, mock_body);

    _ = try withCapturedOutput(&ctx.mock_client, struct {
        fn run(client: *http_mock.MockHttpClient) !void {
            try search.search_packages_with_client(testing.allocator, client, null, "http");
        }
    }.run);

    const requests = ctx.mock_client.getRequests();
    try testing.expectEqual(@as(usize, 1), requests.len);
    try testing.expect(!std.mem.containsAtLeast(u8, requests[0].url, 1, "q="));
    try testing.expect(std.mem.containsAtLeast(u8, requests[0].url, 1, "filter=http"));
}

test "search_packages: empty query and filter returns error" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();

    _ = try withCapturedOutput(&ctx.mock_client, struct {
        fn run(client: *http_mock.MockHttpClient) !void {
            const result = search.search_packages_with_client(testing.allocator, client, null, null);
            try testing.expectError(error.InvalidSearchParameters, result);
        }
    }.run);

    try testing.expectEqual(@as(usize, 0), ctx.mock_client.getRequests().len);
}

test "search_packages: wildcard query treated as empty" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();

    const mock_body = try testing.allocator.dupe(u8,
        \\ [{"avatar_url":"https://avatars.githubusercontent.com/u/201527030?v=4","name":"MLX.zig","full_name":"jaco-bro/MLX.zig","created_at":"2025-03-14T14:47:09Z","description":"MLX.zig: Phi-4, Llama 3.2, and Whisper in Zig","default_branch":"main","open_issues":2,"stargazers_count":28,"forks_count":4,"watchers_count":28,"tags_url":"https://api.github.com/repos/jaco-bro/MLX.zig/tags","license":"Apache-2.0","topics":["llama","llm","mlx","pcre2","regex","tiktoken","zig","zig-package"],"size":5431,"fork":false,"updated_at":"2025-10-02T01:55:39Z","has_build_zig":true,"has_build_zig_zon":true,"zig_minimum_version":"unknown","repo_from":"github","dependencies":[{"name":"pcre2","url":"https://github.com/PCRE2Project/pcre2","commit":"refs","tar_url":"https://github.com/PCRE2Project/pcre2/archive/refs.tar.gz","type":"remote"}],"dependents":[]},{"avatar_url":"https://avatars.githubusercontent.com/u/201527030?v=4","name":"tokenizer","full_name":"jaco-bro/tokenizer","created_at":"2025-04-19T04:26:17Z","description":"BPE tokenizer for LLMs in Pure Zig","default_branch":"main","open_issues":0,"stargazers_count":5,"forks_count":3,"watchers_count":5,"tags_url":"https://api.github.com/repos/jaco-bro/tokenizer/tags","license":"Apache-2.0","topics":["bpe-tokenizer","pcre2","regex","tokenizer","zig","zig-package"],"size":305,"fork":false,"updated_at":"2025-09-10T20:08:12Z","has_build_zig":true,"has_build_zig_zon":true,"zig_minimum_version":"unknown","repo_from":"github","dependencies":[{"name":"pcre2","url":"https://github.com/PCRE2Project/pcre2","commit":"refs","tar_url":"https://github.com/PCRE2Project/pcre2/archive/refs.tar.gz","type":"remote"}],"dependents":["https://github.com/allyourcodebase/boost-libraries-zig"]}]
    );
    defer testing.allocator.free(mock_body);

    try ctx.mock_client.expectRequest("https://api.example.com/search?filter=http", .ok, mock_body);

    _ = try withCapturedOutput(&ctx.mock_client, struct {
        fn run(client: *http_mock.MockHttpClient) !void {
            try search.search_packages_with_client(testing.allocator, client, "*", "http");
        }
    }.run);

    const requests = ctx.mock_client.getRequests();
    try testing.expectEqual(@as(usize, 1), requests.len);
    try testing.expect(!std.mem.containsAtLeast(u8, requests[0].url, 1, "q="));
    try testing.expect(std.mem.containsAtLeast(u8, requests[0].url, 1, "filter=http"));
}

test "search_packages: empty strings treated as null" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();

    const result = search.search_packages_with_client(testing.allocator, &ctx.mock_client, "", "");
    try testing.expectError(error.InvalidSearchParameters, result);
    try testing.expectEqual(@as(usize, 0), ctx.mock_client.getRequests().len);
}

test "search_packages: HTTP non-200 status" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();

    const body = try testing.allocator.dupe(u8, "Not found");
    defer testing.allocator.free(body);

    try ctx.mock_client.expectRequest("https://api.example.com/search?q=test", .not_found, body);

    _ = try withCapturedOutput(&ctx.mock_client, struct {
        fn run(client: *http_mock.MockHttpClient) !void {
            try search.search_packages_with_client(testing.allocator, client, "test", null);
        }
    }.run);

    try testing.expectEqual(@as(usize, 1), ctx.mock_client.getRequests().len);
}

test "search_packages: memory allocation cleanup" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();

    const mock_body = try testing.allocator.dupe(u8,
        \\ [{"name":"test-package","description":"A test package"}]
    );
    defer testing.allocator.free(mock_body);

    try ctx.mock_client.expectRequest("https://api.example.com/search?q=test", .ok, mock_body);

    // Test memory allocation during JSON parsing instead
    var failing = std.testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 1 });

    const result = search.search_packages_with_client(failing.allocator(), &ctx.mock_client, "test", null);
    try testing.expectError(error.OutOfMemory, result);
}
