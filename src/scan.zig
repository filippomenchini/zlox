const std = @import("std");
const Token = @import("token.zig");

pub fn tokens(
    allocator: std.mem.Allocator,
    reader: *std.Io.Reader,
) error{
    UnexpectedCharacter,
    UnterminatedString,
    OutOfMemory,
    ReadFailed,
    EndOfStream,
    StreamTooLong,
}![]Token {
    var list = try std.ArrayList(Token).initCapacity(allocator, 1024);
    errdefer list.deinit(allocator);

    var line: usize = 1;
    var column: usize = 1;

    while (true) {
        const byte = reader.takeByte() catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };

        defer {
            if (byte == '\n') {
                line += 1;
                column = 1;
            } else {
                column += 1;
            }
        }

        var token: ?Token = switch (byte) {
            '(' => .{ .type = .LEFT_PAREN },
            ')' => .{ .type = .RIGHT_PAREN },
            '{' => .{ .type = .LEFT_BRACE },
            '}' => .{ .type = .RIGHT_BRACE },
            ',' => .{ .type = .COMMA },
            '.' => .{ .type = .DOT },
            '-' => .{ .type = .MINUS },
            '+' => .{ .type = .PLUS },
            ';' => .{ .type = .SEMICOLON },
            '*' => .{ .type = .STAR },
            '!' => blk: {
                if (try match(reader, '=')) {
                    reader.toss(1);
                    column += 1;
                    break :blk .{ .type = .BANG_EQUAL };
                }
                break :blk .{ .type = .BANG };
            },
            '=' => blk: {
                if (try match(reader, '=')) {
                    reader.toss(1);
                    column += 1;
                    break :blk .{ .type = .EQUAL_EQUAL };
                }
                break :blk .{ .type = .EQUAL };
            },
            '<' => blk: {
                if (try match(reader, '=')) {
                    reader.toss(1);
                    column += 1;
                    break :blk .{ .type = .LESS_EQUAL };
                }
                break :blk .{ .type = .LESS };
            },
            '>' => blk: {
                if (try match(reader, '=')) {
                    reader.toss(1);
                    column += 1;
                    break :blk .{ .type = .GREATER_EQUAL };
                }
                break :blk .{ .type = .GREATER };
            },
            '/' => blk: {
                if (try match(reader, '/')) {
                    reader.toss(1);
                    column += 1;
                    const peeked = reader.peekDelimiterExclusive('\n') catch |err| switch (err) {
                        error.EndOfStream => break :blk null,
                        else => return err,
                    };
                    reader.toss(peeked.len);
                    column += peeked.len;
                    break :blk null;
                } else {
                    break :blk .{ .type = .SLASH };
                }
            },
            ' ', '\r', '\t', '\n' => null,
            '"' => blk: {
                const string = reader.takeDelimiterExclusive('"') catch |err| switch (err) {
                    error.EndOfStream => return error.UnterminatedString,
                    else => return err,
                };
                const closing_quote = reader.takeByte() catch |err| switch (err) {
                    error.EndOfStream => return error.UnterminatedString,
                    else => return err,
                };

                if (closing_quote != '"') return error.UnterminatedString;

                column += 1;
                for (string) |char| {
                    if (char == '\n') {
                        line += 1;
                        column = 1;
                    } else {
                        column += 1;
                    }
                }

                const owned_string = try allocator.dupe(u8, string);
                break :blk .{ .type = .STRING, .literal = .{ .string = owned_string } };
            },
            else => return error.UnexpectedCharacter,
        };

        if (token == null) continue;

        token.?.line = line;
        token.?.column = column;
        std.debug.assert(token.?.column != 0 and token.?.line != 0);

        list.appendAssumeCapacity(token.?);
    }

    return list.toOwnedSlice(allocator);
}

fn match(reader: *std.Io.Reader, char: u8) !bool {
    const next_byte = reader.peekByte() catch |err| switch (err) {
        error.EndOfStream => return false,
        else => return err,
    };

    return next_byte == char;
}
