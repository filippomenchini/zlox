const std = @import("std");

pub fn prompt(input: *std.Io.Reader, ouput: *std.Io.Writer) !void {
    while (true) {
        try ouput.print("> ", .{});
        try ouput.flush();
        const line = try input.takeDelimiterExclusive('\n');
        const should_continue = try run(line);
        if (!should_continue) break;
    }
}

pub fn file(path: []const u8) !void {
    _ = try run(path);
}

fn run(bytes: []const u8) !bool {
    if (bytes.len == 0) return true;
    if (std.mem.eql(u8, bytes, "exit")) return false;
    std.debug.print("Running code: {s}\n", .{bytes});
    return true;
}
