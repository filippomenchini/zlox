const std = @import("std");

pub fn prompt(input: *std.Io.Reader, output: *std.Io.Writer) !void {
    try output.print("zlox - REPL v0.1.0\n", .{});
    while (true) {
        try output.print("> ", .{});
        try output.flush();
        const should_continue = try run(input);
        if (!should_continue) break;
    }
}

pub fn file(path: []const u8) !void {
    const f = try std.fs.cwd().openFile(path, .{});
    var buffer: [4096]u8 = undefined;
    var f_r = f.reader(&buffer);
    const f_ri = &f_r.interface;

    while (true) {
        if (f_r.atEnd()) break;
        _ = try run(f_ri);
    }
}

fn run(reader: *std.Io.Reader) !bool {
    const bytes = reader.takeDelimiterExclusive('\n') catch |err| switch (err) {
        error.EndOfStream => return false,
        else => return err,
    };

    if (bytes.len == 0) return true;
    if (std.mem.eql(u8, bytes, "exit")) return false;

    std.debug.print("Running code: {s}\n", .{bytes});
    return true;
}
