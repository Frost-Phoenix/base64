const std = @import("std");
const print = std.debug.print;

const Base64 = @import("base64.zig").Base64;

// ********** //

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const base64: Base64 = .init(allocator);

    const encoded = try base64.encode("Base64 encoded string :)");
    defer allocator.free(encoded);

    print("{s}\n", .{encoded});
}

test {
    _ = @import("base64.zig");
}
