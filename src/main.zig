const std = @import("std");
const zlox = @import("zlox");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var stdout_buf: [4096]u8 = undefined;
    const stdout = std.fs.File.stdout();
    var stdout_w = stdout.writer(&stdout_buf);
    const stdout_wi = &stdout_w.interface;

    var stdin_buf: [4096]u8 = undefined;
    const stdin = std.fs.File.stdin();
    var stdin_r = stdin.reader(&stdin_buf);
    const stdin_ri = &stdin_r.interface;

    var args = try std.process.argsWithAllocator(allocator);

    var i: usize = 0;
    var arg = args.next();
    var script: ?[]const u8 = null;
    while (arg != null) : (i += 1) {
        if (i > 1) {
            try stdout_wi.print("Usage: zlox [script]\n", .{});
            try stdout_wi.flush();
            return;
        }

        if (i == 1) script = std.mem.span(arg.?.ptr);

        arg = args.next();
    }

    if (script != null) {
        try zlox.runner.file(script.?);
        return;
    }

    try zlox.runner.prompt(stdin_ri, stdout_wi);
}
