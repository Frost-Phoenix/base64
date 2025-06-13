const std = @import("std");

const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const print = std.debug.print;

// ********** //

const chr = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const padding = '=';

fn getEncodedSize(data: []const u8) usize {
    return ((data.len + 2) / 3) * 4;
}

fn getChar(idx: usize) u8 {
    assert(idx < 64);

    return chr[idx];
}

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const encoded = try encode(allocator, "test");
    defer allocator.free(encoded);

    print("{s}\n", .{encoded});
}

fn encode(allocator: Allocator, data: []const u8) ![]const u8 {
    const encoded_size = getEncodedSize(data);
    const encoded = try allocator.alloc(u8, encoded_size);

    const nb_full_chunks = data.len / 3;
    for (0..nb_full_chunks) |i| {
        const data_idx = i * 3;

        encoded[i + 0] = getChar(data[data_idx] >> 2);
        encoded[i + 1] = getChar(((data[data_idx] & 0x03) << 4) | (data[data_idx + 1] >> 4));
        encoded[i + 2] = getChar(((data[data_idx + 1] & 0x0f) << 2) | (data[data_idx + 2] >> 6));
        encoded[i + 3] = getChar(data[data_idx + 2] & 0b00111111);
    }

    if (data.len % 3 == 2) {
        encoded[encoded_size - 4] = getChar(data[data.len - 2] >> 2);
        encoded[encoded_size - 3] = getChar(((data[data.len - 2] & 0x03) << 4) | (data[data.len - 1] >> 4));
        encoded[encoded_size - 2] = getChar((data[data.len - 1] & 0x0f) << 2);
        encoded[encoded_size - 1] = padding;
    } else if (data.len % 3 == 1) {
        encoded[encoded_size - 4] = getChar(data[data.len - 1] >> 2);
        encoded[encoded_size - 3] = getChar(((data[data.len - 1] & 0x03) << 4));
        encoded[encoded_size - 2] = padding;
        encoded[encoded_size - 1] = padding;
    }

    return encoded;
}
