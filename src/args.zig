const std = @import("std");
const print = std.debug.print;
const eql = std.mem.eql;

const Allocator = std.mem.Allocator;

// ********** //

pub const Options = struct {
    line_wrap: u32,
    decode: bool,
    ignore_garbage: bool,
    file: ?[]const u8,

    const default = Options{
        .line_wrap = 76,
        .decode = false,
        .ignore_garbage = false,
        .file = null,
    };

    pub fn deinit(self: *const Options, allocator: Allocator) void {
        if (self.file) |file| {
            allocator.free(file);
        }
    }
};

pub fn parseArgs(allocator: Allocator) !Options {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.process.exit(1);
    }

    var options: Options = .default;

    const name = args[0];

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.startsWith(u8, arg, "--")) {
            if (eql(u8, arg[2..], "help")) {
                try printHelp();
            } else if (eql(u8, arg[2..], "decode")) {
                options.decode = true;
            } else if (eql(u8, arg[2..], "ignore-garbage")) {
                options.ignore_garbage = true;
            } else if (eql(u8, arg[2..], "wrap")) {
                i += 1;
                if (!(i < args.len)) {
                    try exitError(name, "{s}: option '{s}' requires an argument\n", .{ name, arg });
                }
                options.line_wrap = try std.fmt.parseUnsigned(u32, args[i], 0);
            } else {
                try exitError(name, "{s}: unrecognized option '{s}'\n", .{ name, arg });
            }
        } else if (std.mem.startsWith(u8, arg, "-")) {
            for (arg[1..]) |c| {
                switch (c) {
                    'h' => try printHelp(),
                    'd' => options.decode = true,
                    'i' => options.ignore_garbage = true,
                    'w' => {
                        i += 1;
                        if (!(i < args.len)) {
                            try exitError(name, "{s}: option '-{c}' requires an argument\n", .{ name, c });
                        }
                        options.line_wrap = try std.fmt.parseUnsigned(u32, args[i], 0);
                    },
                    else => try exitError(name, "{s}: unrecognized option '-{c}'\n", .{ name, c }),
                }
            }
        } else {
            if (options.file != null) {
                try exitError(name, "{s}: extra operand '{s}'\n", .{ name, arg });
            }

            options.file = try allocator.dupe(u8, arg);
        }
    }

    return options;
}

fn exitError(name: []const u8, comptime msg: []const u8, args: anytype) !void {
    const stderr_writer = std.io.getStdErr().writer();

    try std.fmt.format(stderr_writer, msg, args);
    try std.fmt.format(stderr_writer, "Try '{s} --help' for more information.\n", .{name});

    std.process.exit(1);
}

fn printHelp() !void {
    const stdout = std.io.getStdOut();
    try stdout.writeAll(
        \\Usage: base64 [OPTION]... [FILE]
        \\Base64 encode or decode FILE, or standard input, to standard output.
        \\
        \\With no FILE, or when FILE is -, read standard input.
        \\
        \\  -d, --decode          decode data
        \\  -i, --ignore-garbage  when decoding, ignore non-alphabet characters
        \\  -w, --wrap=COLS       wrap encoded lines after COLS character (default 76).
        \\                        Use 0 to disable line wrapping
        \\
        \\      --help            display this help and exit
        \\      --version         output version information and exit
    );
    try stdout.writeAll("\n");

    std.process.exit(0);
}
