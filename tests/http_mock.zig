const std = @import("std");
const testing = std.testing;
const http = std.http;

// Mock HTTP Client
pub const MockHttpClient = struct {
    allocator: std.mem.Allocator,
    expected_urls: std.ArrayList([]const u8),
    responses: std.ArrayList(MockResponse),
    requests_made: std.ArrayList(MockRequest),

    const MockResponse = struct {
        status: http.Status,
        body: []const u8,
    };

    const MockRequest = struct {
        url: []const u8,
        method: ?http.Method,
    };

    pub fn init(allocator: std.mem.Allocator) MockHttpClient {
        return .{
            .allocator = allocator,
            .expected_urls = std.ArrayList([]const u8){},
            .responses = std.ArrayList(MockResponse){},
            .requests_made = std.ArrayList(MockRequest){},
        };
    }

    pub fn deinit(self: *MockHttpClient) void {
        std.debug.print("Deinit called - freeing {} URLs, {} responses, {} requests\n", .{
            self.expected_urls.items.len,
            self.responses.items.len,
            self.requests_made.items.len,
        });

        for (self.expected_urls.items) |url| {
            std.debug.print("Freeing expected URL: {s}\n", .{url});
            self.allocator.free(url);
        }
        self.expected_urls.deinit(self.allocator);

        // Free any remaining response bodies
        for (self.responses.items) |response| {
            std.debug.print("Freeing remaining response body length: {}\n", .{response.body.len});
            self.allocator.free(response.body);
        }
        self.responses.deinit(self.allocator);

        for (self.requests_made.items) |req| {
            std.debug.print("Freeing request URL: {s}\n", .{req.url});
            self.allocator.free(req.url);
        }
        self.requests_made.deinit(self.allocator);
    }

    pub fn expectRequest(self: *MockHttpClient, url: []const u8, status: http.Status, response_body: []const u8) !void {
        const url_copy = try self.allocator.dupe(u8, url);
        const body_copy = try self.allocator.dupe(u8, response_body);

        try self.expected_urls.append(self.allocator, url_copy);
        try self.responses.append(self.allocator, .{
            .status = status,
            .body = body_copy,
        });
    }

    pub fn fetch(self: *MockHttpClient, options: http.Client.FetchOptions) !http.Client.FetchResult {
        // Store the request for verification
        const url_copy = try self.allocator.dupe(u8, options.location.url);
        try self.requests_made.append(self.allocator, .{
            .url = url_copy,
            .method = options.method,
        });

        // Check if we have a response for this request
        if (self.responses.items.len == 0) {
            return error.NoExpectedResponse;
        }

        const expected_response = self.responses.orderedRemove(0);

        // Write response body to the provided writer
        if (options.response_writer) |writer| {
            try writer.writeAll(expected_response.body);
        }

        // FREE THE RESPONSE BODY AFTER USE!
        self.allocator.free(expected_response.body);

        return http.Client.FetchResult{
            .status = expected_response.status,
        };
    }

    pub fn getRequests(self: *const MockHttpClient) []const MockRequest {
        return self.requests_made.items;
    }

    pub fn clearRequests(self: *MockHttpClient) void {
        self.requests_made.clearRetainingCapacity();
    }
};
