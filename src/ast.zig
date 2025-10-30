const std = @import("std");
const Token = @import("token.zig");

pub const Grouping = *const Expr;
pub const Literal = Token.Literal;
pub const Unary = struct { operator: Token, expr: *const Expr };
pub const Binary = struct { operator: Token, left: *const Expr, right: *const Expr };
pub const Expr = union(enum) {
    binary: Binary,
    grouping: Grouping,
    literal: Literal,
    unary: Unary,
};

pub fn print(expr: *const Expr, output: *std.Io.Writer) !void {
    switch (expr.*) {
        .literal => |l| {
            switch (l) {
                .number => |n| try output.print("{d}", .{n}),
                .boolean => |b| try output.print("{s}", if (b) .{"true"} else .{"false"}),
                .string => |s| try output.print("{s}", .{s}),

                .none => try output.print("nil", .{}),
            }
        },
        .unary => |u| {
            try output.print("({s} ", .{u.operator.lexeme});
            try print(u.expr, output);
            try output.writeByte(')');
        },
        .binary => |b| {
            try output.print("({s} ", .{b.operator.lexeme});
            try print(b.left, output);
            try output.writeByte(' ');
            try print(b.right, output);
            try output.writeByte(')');
        },
        .grouping => |g| {
            try output.print("(group ", .{});
            try print(g, output);
            try output.writeByte(')');
        },
    }
    try output.flush();
}

test "expr" {
    var aw = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer aw.deinit();

    const left = Expr{
        .unary = .{
            .operator = .{ .type = .MINUS, .lexeme = "-" },
            .expr = &.{
                .literal = .{ .number = 123 },
            },
        },
    };

    const right = Expr{
        .grouping = &.{
            .literal = .{ .number = 45.67 },
        },
    };

    const expr = Expr{
        .binary = .{
            .left = &left,
            .right = &right,
            .operator = .{ .type = .STAR, .lexeme = "*" },
        },
    };

    try print(&expr, &aw.writer);
    try std.testing.expectEqualSlices(u8, "(* (- 123) (group 45.67))", aw.written());
}
