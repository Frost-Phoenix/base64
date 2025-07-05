const std = @import("std");

const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;

// ********** //

const DecodeError = error{
    InvalideChar,
};

pub const Base64 = struct {
    allocator: Allocator,

    const Self = @This();

    const encode_table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    const padding = '=';

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    fn getEncodedSize(data: []const u8) usize {
        return ((data.len + 2) / 3) * 4;
    }

    fn getDecodedSize(data: []const u8) usize {
        var size = data.len / 4 * 3;

        if (std.mem.endsWith(u8, data, "==")) {
            size -= 2;
        } else if (std.mem.endsWith(u8, data, "=")) {
            size -= 1;
        }

        return size;
    }

    fn getEncodedChr(idx: usize) u8 {
        assert(idx < 64);

        return encode_table[idx];
    }

    fn getDecodedIdx(chr: u8) DecodeError!u8 {
        return switch (chr) {
            '=' => 0,
            'A'...'Z' => |c| c - 'A',
            'a'...'z' => |c| c - 'a' + 26,
            '0'...'9' => |c| c - '0' + 52,
            '+' => 62,
            '/' => 63,
            else => {
                return DecodeError.InvalideChar;
            },
        };
    }

    pub fn encode(self: *const Self, data: []const u8) ![]const u8 {
        if (data.len == 0) {
            return "";
        }

        const encoded_size = getEncodedSize(data);
        const encoded = try self.allocator.alloc(u8, encoded_size);
        errdefer self.allocator.free(encoded);

        const nb_full_chunks = data.len / 3;
        for (0..nb_full_chunks) |i| {
            const encoded_idx = i * 3;

            encoded[i * 4 + 0] = getEncodedChr(data[encoded_idx] >> 2);
            encoded[i * 4 + 1] = getEncodedChr(((data[encoded_idx] & 0x03) << 4) | (data[encoded_idx + 1] >> 4));
            encoded[i * 4 + 2] = getEncodedChr(((data[encoded_idx + 1] & 0x0f) << 2) | (data[encoded_idx + 2] >> 6));
            encoded[i * 4 + 3] = getEncodedChr(data[encoded_idx + 2] & 0x3f);
        }

        if (data.len % 3 == 2) {
            encoded[encoded_size - 4] = getEncodedChr(data[data.len - 2] >> 2);
            encoded[encoded_size - 3] = getEncodedChr(((data[data.len - 2] & 0x03) << 4) | (data[data.len - 1] >> 4));
            encoded[encoded_size - 2] = getEncodedChr((data[data.len - 1] & 0x0f) << 2);
            encoded[encoded_size - 1] = padding;
        } else if (data.len % 3 == 1) {
            encoded[encoded_size - 4] = getEncodedChr(data[data.len - 1] >> 2);
            encoded[encoded_size - 3] = getEncodedChr(((data[data.len - 1] & 0x03) << 4));
            encoded[encoded_size - 2] = padding;
            encoded[encoded_size - 1] = padding;
        }

        return encoded;
    }

    pub fn decode(self: *const Self, data: []const u8) ![]const u8 {
        if (data.len == 0) {
            return "";
        }

        const decoded_size = getDecodedSize(data);
        const decoded = try self.allocator.alloc(u8, decoded_size);
        errdefer self.allocator.free(decoded);

        const nb_chunks = data.len / 4;
        for (0..nb_chunks - 1) |i| {
            const idx = i * 4;

            decoded[i * 3 + 0] = (try getDecodedIdx(data[idx]) << 2) | (try getDecodedIdx(data[idx + 1]) >> 4);
            decoded[i * 3 + 1] = (try getDecodedIdx(data[idx + 1]) << 4) | (try getDecodedIdx(data[idx + 2]) >> 2);
            decoded[i * 3 + 2] = (try getDecodedIdx(data[idx + 2]) << 6) | (try getDecodedIdx(data[idx + 3]));
        }

        if (!std.mem.endsWith(u8, data, "=")) {
            decoded[decoded_size - 3] = (try getDecodedIdx(data[data.len - 4]) << 2) | (try getDecodedIdx(data[data.len - 3]) >> 4);
            decoded[decoded_size - 2] = (try getDecodedIdx(data[data.len - 3]) << 4) | (try getDecodedIdx(data[data.len - 2]) >> 2);
            decoded[decoded_size - 1] = (try getDecodedIdx(data[data.len - 2]) << 6) | (try getDecodedIdx(data[data.len - 1]));
        } else if (std.mem.endsWith(u8, data, "==")) {
            decoded[decoded_size - 1] = (try getDecodedIdx(data[data.len - 4]) << 2) | (try getDecodedIdx(data[data.len - 3]) >> 4);
        } else {
            decoded[decoded_size - 2] = (try getDecodedIdx(data[data.len - 4]) << 2) | (try getDecodedIdx(data[data.len - 3]) >> 4);
            decoded[decoded_size - 1] = (try getDecodedIdx(data[data.len - 3]) << 4) | (try getDecodedIdx(data[data.len - 2]) >> 2);
        }

        return decoded;
    }
};

test "encode" {
    const test_allocator = std.testing.allocator;

    const base64: Base64 = .init(test_allocator);

    const no_padding = "simple test.";
    const one_padding = "simple test";
    const two_padding = "simpletest";
    const empty = "";

    const no_padding_encoded = try base64.encode(no_padding);
    const one_padding_encoded = try base64.encode(one_padding);
    const two_padding_encoded = try base64.encode(two_padding);
    const empty_encoded = try base64.encode(empty);

    defer test_allocator.free(no_padding_encoded);
    defer test_allocator.free(one_padding_encoded);
    defer test_allocator.free(two_padding_encoded);
    defer test_allocator.free(empty_encoded);

    try expectEqualSlices(u8, "c2ltcGxlIHRlc3Qu", no_padding_encoded);
    try expectEqualSlices(u8, "c2ltcGxlIHRlc3Q=", one_padding_encoded);
    try expectEqualSlices(u8, "c2ltcGxldGVzdA==", two_padding_encoded);
    try expectEqualSlices(u8, "", empty_encoded);
    try expect(empty_encoded.len == 0);
}

test "decode" {
    const test_allocator = std.testing.allocator;

    const base64: Base64 = .init(test_allocator);

    const no_padding = "simple test.";
    const one_padding = "simple test";
    const two_padding = "simpletest";
    const empty = "";

    const no_padding_encoded = try base64.encode(no_padding);
    const one_padding_encoded = try base64.encode(one_padding);
    const two_padding_encoded = try base64.encode(two_padding);
    const empty_encoded = try base64.encode(empty);

    defer test_allocator.free(no_padding_encoded);
    defer test_allocator.free(one_padding_encoded);
    defer test_allocator.free(two_padding_encoded);
    defer test_allocator.free(empty_encoded);

    const no_padding_decoded = try base64.decode(no_padding_encoded);
    const one_padding_decoded = try base64.decode(one_padding_encoded);
    const two_padding_decoded = try base64.decode(two_padding_encoded);
    const empty_decoded = try base64.decode(empty_encoded);

    defer test_allocator.free(no_padding_decoded);
    defer test_allocator.free(one_padding_decoded);
    defer test_allocator.free(two_padding_decoded);
    defer test_allocator.free(empty_decoded);

    try expectEqualSlices(u8, no_padding, no_padding_decoded);
    try expectEqualSlices(u8, one_padding, one_padding_decoded);
    try expectEqualSlices(u8, two_padding, two_padding_decoded);
    try expectEqualSlices(u8, empty, empty_decoded);
    try expect(empty_decoded.len == 0);
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;
const expectEqualSlices = std.testing.expectEqualSlices;
