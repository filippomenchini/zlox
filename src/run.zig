const std = @import("std");
const scan = @import("scan.zig");

pub fn prompt(allocator: std.mem.Allocator, input: *std.Io.Reader, output: *std.Io.Writer) !void {
    try output.print("zlox - REPL v0.1.0\n", .{});
    while (true) {
        try output.print("> ", .{});
        try output.flush();

        const bytes = try input.takeDelimiterExclusive('\n');
        input.toss(1); //Tossing '\n' otherwise we get stuck in a loop.

        var bytes_reader = std.Io.Reader.fixed(bytes);
        const state = try run(allocator, &bytes_reader);
        switch (state.status) {
            else => {},
            .done => break,
        }
    }
}

pub fn file(allocator: std.mem.Allocator, path: []const u8) !void {
    const f = try std.fs.cwd().openFile(path, .{});
    var buffer: [4096]u8 = undefined;
    var f_r = f.reader(&buffer);

    while (true) {
        const state = try run(allocator, &f_r.interface);
        switch (state.status) {
            else => {},
            .err, .done => break,
        }
    }
}

const State = struct {
    status: enum {
        ok, // Everything is ok, we can go to next instruction
        err, // We have an error, we MUST halt the interpreter
        done, // Program reached the end, we can stop the interpreter
    } = .ok,
};

fn run(allocator: std.mem.Allocator, reader: *std.Io.Reader) !State {
    const tokens = scan.tokens(allocator, reader) catch |err| switch (err) {
        else => return err,
    };
    defer allocator.free(tokens);

    std.debug.print("{any}\n", .{tokens});
    return .{ .status = .ok };
}
