const std = @import("std");
const print = std.debug.print;

const Base64 = @import("base64.zig").Base64;
const args = @import("args.zig");

// ********** //

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const options = try args.parseArgs(allocator);
    defer options.deinit(allocator);

    print("{any}\n", .{options});

    const base64: Base64 = .init(allocator);

    const encoded = try base64.encode("Base64 encoded string :)");
    defer allocator.free(encoded);

    print("{s}\n", .{encoded});
}

test {
    _ = @import("base64.zig");
}
