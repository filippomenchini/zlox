const std = @import("std");

pub fn main() !void {
    var da: std.heap.DebugAllocator(.{}) = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    var stdout_buf: [4096]u8 = undefined;
    const stdout = std.fs.File.stdout();
    var stdout_w = stdout.writer(&stdout_buf);
    var stdout_wi = &stdout_w.interface;

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
}
