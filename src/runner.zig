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
    _ = path;
    // _ = try run(path);
}

fn run(reader: *std.Io.Reader) !bool {
    const bytes = try reader.takeDelimiterExclusive('\n');
    reader.toss(1);

    if (bytes.len == 0) return true;
    if (std.mem.eql(u8, bytes, "exit")) return false;

    std.debug.print("Running code: {s}\n", .{bytes});
    return true;
}
