const std = @import("std");

const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;

// ********** //

const chr = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const padding = '=';

// ********** //

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const encoded = try encode(allocator, "Base64 encoded string :)");
    defer allocator.free(encoded);

    print("{s}\n", .{encoded});
}

fn getEncodedSize(data: []const u8) usize {
    return ((data.len + 2) / 3) * 4;
}

fn getEncodedChr(idx: usize) u8 {
    assert(idx < 64);

    return chr[idx];
}

fn encode(allocator: Allocator, data: []const u8) ![]const u8 {
    const encoded_size = getEncodedSize(data);
    const encoded = try allocator.alloc(u8, encoded_size);

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

test "encode" {
    const test_allocator = std.testing.allocator;

    const no_padding = try encode(test_allocator, "simple test.");
    const one_padding = try encode(test_allocator, "simple test");
    const two_padding = try encode(test_allocator, "simpletest");
    const empty = try encode(test_allocator, "");

    defer test_allocator.free(no_padding);
    defer test_allocator.free(one_padding);
    defer test_allocator.free(two_padding);
    defer test_allocator.free(empty);

    try std.testing.expectEqualSlices(u8, "c2ltcGxlIHRlc3Qu", no_padding);
    try std.testing.expectEqualSlices(u8, "c2ltcGxlIHRlc3Q=", one_padding);
    try std.testing.expectEqualSlices(u8, "", empty);
    try std.testing.expect(empty.len == 0);
}
