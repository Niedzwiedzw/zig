//! This API is a barely-touched, barely-functional http client, just the
//! absolute minimum thing I needed in order to test `std.crypto.tls`. Bear
//! with me and I promise the API will become useful and streamlined.

const std = @import("../std.zig");
const assert = std.debug.assert;
const http = std.http;
const net = std.net;
const Client = @This();
const Url = std.Url;

allocator: std.mem.Allocator,
headers: std.ArrayListUnmanaged(u8) = .{},
active_requests: usize = 0,
ca_bundle: std.crypto.Certificate.Bundle = .{},

/// TODO: emit error.UnexpectedEndOfStream or something like that when the read
/// data does not match the content length. This is necessary since HTTPS disables
/// close_notify protection on underlying TLS streams.
pub const Request = struct {
    client: *Client,
    stream: net.Stream,
    headers: std.ArrayListUnmanaged(u8) = .{},
    tls_client: std.crypto.tls.Client,
    protocol: Protocol,
    response_headers: http.Headers = .{},

    pub const Protocol = enum { http, https };

    pub const Options = struct {
        method: http.Method = .GET,
    };

    pub fn deinit(req: *Request) void {
        req.client.active_requests -= 1;
        req.headers.deinit(req.client.allocator);
        req.* = undefined;
    }

    pub fn addHeader(req: *Request, name: []const u8, value: []const u8) !void {
        const gpa = req.client.allocator;
        // Ensure an extra +2 for the \r\n in end()
        try req.headers.ensureUnusedCapacity(gpa, name.len + value.len + 6);
        req.headers.appendSliceAssumeCapacity(name);
        req.headers.appendSliceAssumeCapacity(": ");
        req.headers.appendSliceAssumeCapacity(value);
        req.headers.appendSliceAssumeCapacity("\r\n");
    }

    pub fn end(req: *Request) !void {
        req.headers.appendSliceAssumeCapacity("\r\n");
        switch (req.protocol) {
            .http => {
                try req.stream.writeAll(req.headers.items);
            },
            .https => {
                try req.tls_client.writeAll(req.stream, req.headers.items);
            },
        }
    }

    pub fn readAll(req: *Request, buffer: []u8) !usize {
        return readAtLeast(req, buffer, buffer.len);
    }

    pub fn read(req: *Request, buffer: []u8) !usize {
        return readAtLeast(req, buffer, 1);
    }

    pub fn readAtLeast(req: *Request, buffer: []u8, len: usize) !usize {
        assert(len <= buffer.len);
        var index: usize = 0;
        while (index < len) {
            const headers_finished = req.response_headers.state == .finished;
            const amt = try readAdvanced(req, buffer[index..]);
            if (amt == 0 and headers_finished) break;
            index += amt;
        }
        return index;
    }

    /// This one can return 0 without meaning EOF.
    /// TODO change to readvAdvanced
    pub fn readAdvanced(req: *Request, buffer: []u8) !usize {
        if (req.response_headers.state == .finished) return readRaw(req, buffer);

        const amt = try readRaw(req, buffer);
        const data = buffer[0..amt];
        const i = req.response_headers.feed(data);
        if (req.response_headers.state == .invalid) return error.InvalidHttpHeaders;
        if (i < data.len) {
            const rest = data[i..];
            std.mem.copy(u8, buffer, rest);
            return rest.len;
        }
        return 0;
    }

    /// Only abstracts over http/https.
    fn readRaw(req: *Request, buffer: []u8) !usize {
        switch (req.protocol) {
            .http => return req.stream.read(buffer),
            .https => return req.tls_client.read(req.stream, buffer),
        }
    }

    /// Only abstracts over http/https.
    fn readAtLeastRaw(req: *Request, buffer: []u8, len: usize) !usize {
        switch (req.protocol) {
            .http => return req.stream.readAtLeast(buffer, len),
            .https => return req.tls_client.readAtLeast(req.stream, buffer, len),
        }
    }
};

pub fn deinit(client: *Client) void {
    assert(client.active_requests == 0);
    client.headers.deinit(client.allocator);
    client.* = undefined;
}

pub fn request(client: *Client, url: Url, options: Request.Options) !Request {
    const protocol = std.meta.stringToEnum(Request.Protocol, url.scheme) orelse
        return error.UnsupportedUrlScheme;
    const port: u16 = url.port orelse switch (protocol) {
        .http => 80,
        .https => 443,
    };

    var req: Request = .{
        .client = client,
        .stream = try net.tcpConnectToHost(client.allocator, url.host, port),
        .protocol = protocol,
        .tls_client = undefined,
    };
    client.active_requests += 1;
    errdefer req.deinit();

    switch (protocol) {
        .http => {},
        .https => {
            req.tls_client = try std.crypto.tls.Client.init(req.stream, client.ca_bundle, url.host);
            // This is appropriate for HTTPS because the HTTP headers contain
            // the content length which is used to detect truncation attacks.
            req.tls_client.allow_truncation_attacks = true;
        },
    }

    try req.headers.ensureUnusedCapacity(
        client.allocator,
        @tagName(options.method).len +
            1 +
            url.path.len +
            " HTTP/1.1\r\nHost: ".len +
            url.host.len +
            "\r\nUpgrade-Insecure-Requests: 1\r\n".len +
            client.headers.items.len +
            2, // for the \r\n at the end of headers
    );
    req.headers.appendSliceAssumeCapacity(@tagName(options.method));
    req.headers.appendSliceAssumeCapacity(" ");
    req.headers.appendSliceAssumeCapacity(url.path);
    req.headers.appendSliceAssumeCapacity(" HTTP/1.1\r\nHost: ");
    req.headers.appendSliceAssumeCapacity(url.host);
    switch (protocol) {
        .https => req.headers.appendSliceAssumeCapacity("\r\nUpgrade-Insecure-Requests: 1\r\n"),
        .http => req.headers.appendSliceAssumeCapacity("\r\n"),
    }
    req.headers.appendSliceAssumeCapacity(client.headers.items);

    return req;
}

pub fn addHeader(client: *Client, name: []const u8, value: []const u8) !void {
    const gpa = client.allocator;
    try client.headers.ensureUnusedCapacity(gpa, name.len + value.len + 4);
    client.headers.appendSliceAssumeCapacity(name);
    client.headers.appendSliceAssumeCapacity(": ");
    client.headers.appendSliceAssumeCapacity(value);
    client.headers.appendSliceAssumeCapacity("\r\n");
}
