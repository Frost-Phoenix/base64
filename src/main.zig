const std = @import("std");
const print = std.debug.print;

const Base64 = @import("base64.zig").Base64;
const args = @import("args.zig");

const exitError = @import("common.zig").exitError;

// ********** //

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const options = try args.parseArgs(allocator);
    defer options.deinit(allocator);

    if (options.file) |path| {
        const file = std.fs.cwd().openFile(path, .{}) catch {
            try exitError("base64: {s}: No such file or directory\n", .{path});
            unreachable;
        };
        defer file.close();

        const file_size = (try file.stat()).size;

        const file_data = try allocator.alloc(u8, file_size);
        defer allocator.free(file_data);

        const byte_read = try file.readAll(file_data);
        if (byte_read != file_size) {
            return error.IncompleteRead;
        }

        const base64: Base64 = .init(allocator, options.ignore_garbage);

        const result = blk: {
            if (options.decode) {
                break :blk try base64.decode(file_data);
            } else {
                break :blk try base64.encode(file_data);
            }
        };
        defer allocator.free(result);

        const stdout = std.io.getStdOut();

        if (options.decode or options.line_wrap == 0) {
            try stdout.writeAll(result);
        } else {
            const len = result.len;
            const line_wrap = options.line_wrap;

            var i: usize = 0;
            while (i < len) : (i += line_wrap) {
                const end = @min(i + line_wrap, len);

                try stdout.writeAll(result[i..end]);
                try stdout.writeAll("\n");
            }
        }
    }
}

test {
    _ = @import("base64.zig");
}
