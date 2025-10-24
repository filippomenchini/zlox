const std = @import("std");

pub fn prompt(input: *std.Io.Reader, output: *std.Io.Writer) !void {
    try output.print("zlox - REPL v0.1.0\n", .{});
    while (true) {
        try output.print("> ", .{});
        try output.flush();
        const state = run(input);
        switch (state.status) {
            else => {},
            .done => break,
        }
    }
}

pub fn file(path: []const u8) !void {
    const f = try std.fs.cwd().openFile(path, .{});
    var buffer: [4096]u8 = undefined;
    var f_r = f.reader(&buffer);

    while (true) {
        const state = run(&f_r.interface);
        switch (state.status) {
            else => {},
            .err, .done => break,
        }
    }
}

const RunState = struct {
    status: enum { ok, err, done } = .ok,
};
fn run(reader: *std.Io.Reader) RunState {
    const bytes = reader.takeDelimiterExclusive('\n') catch |err| switch (err) {
        error.EndOfStream => return .{ .status = .done },
        else => return .{ .status = .err },
    };

    if (bytes.len == 0) return .{ .status = .ok };
    if (std.mem.eql(u8, bytes, "exit")) return .{ .status = .done };

    std.debug.print("Running code: {s}\n", .{bytes});
    return .{ .status = .ok };
}
