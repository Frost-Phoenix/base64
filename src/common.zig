const std = @import("std");

// ********** //

pub fn exitError(comptime msg: []const u8, args: anytype) !void {
    const stderr_writer = std.io.getStdErr().writer();

    try std.fmt.format(stderr_writer, msg, args);
    try stderr_writer.writeAll("Try 'base64 --help' for more information.\n");

    std.process.exit(1);
}
