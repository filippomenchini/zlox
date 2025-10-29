const std = @import("std");
const Token = @import("token.zig");

const keywords = std.StaticStringMap(Token.Type).initComptime(.{
    .{ "and", .AND },
    .{ "class", .CLASS },
    .{ "else", .ELSE },
    .{ "false", .FALSE },
    .{ "for", .FOR },
    .{ "fun", .FUN },
    .{ "if", .IF },
    .{ "nil", .NIL },
    .{ "or", .OR },
    .{ "print", .PRINT },
    .{ "return", .RETURN },
    .{ "super", .SUPER },
    .{ "this", .THIS },
    .{ "true", .TRUE },
    .{ "var", .VAR },
    .{ "while", .WHILE },
});

pub fn tokens(
    allocator: std.mem.Allocator,
    reader: *std.Io.Reader,
) error{
    UnexpectedCharacter,
    UnterminatedString,
    UnterminatedComment,
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
        const start_line = line;
        const start_column = column;

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
            '(' => .{ .type = .LEFT_PAREN, .lexeme = "(" },
            ')' => .{ .type = .RIGHT_PAREN, .lexeme = ")" },
            '{' => .{ .type = .LEFT_BRACE, .lexeme = "{" },
            '}' => .{ .type = .RIGHT_BRACE, .lexeme = "}" },
            ',' => .{ .type = .COMMA, .lexeme = "," },
            '.' => .{ .type = .DOT, .lexeme = "." },
            '-' => .{ .type = .MINUS, .lexeme = "-" },
            '+' => .{ .type = .PLUS, .lexeme = "+" },
            ';' => .{ .type = .SEMICOLON, .lexeme = ";" },
            '*' => .{ .type = .STAR, .lexeme = "*" },
            '!' => blk: {
                if (try match(reader, '=')) {
                    reader.toss(1);
                    column += 1;
                    break :blk .{ .type = .BANG_EQUAL, .lexeme = "!=" };
                }
                break :blk .{ .type = .BANG, .lexeme = "!" };
            },
            '=' => blk: {
                if (try match(reader, '=')) {
                    reader.toss(1);
                    column += 1;
                    break :blk .{ .type = .EQUAL_EQUAL, .lexeme = "==" };
                }
                break :blk .{ .type = .EQUAL, .lexeme = "=" };
            },
            '<' => blk: {
                if (try match(reader, '=')) {
                    reader.toss(1);
                    column += 1;
                    break :blk .{ .type = .LESS_EQUAL, .lexeme = "<=" };
                }
                break :blk .{ .type = .LESS, .lexeme = "<" };
            },
            '>' => blk: {
                if (try match(reader, '=')) {
                    reader.toss(1);
                    column += 1;
                    break :blk .{ .type = .GREATER_EQUAL, .lexeme = ">=" };
                }
                break :blk .{ .type = .GREATER, .lexeme = ">" };
            },
            '/' => blk: {
                if (try match(reader, '/')) {
                    reader.toss(1);
                    column += 1;
                    const peeked = reader.peekDelimiterExclusive('\n') catch |err| switch (err) {
                        error.EndOfStream => break,
                        else => return err,
                    };
                    reader.toss(peeked.len);
                    column += peeked.len;
                    break :blk null;
                } else if (try match(reader, '*')) {
                    reader.toss(1);
                    column += 1;
                    var nesting_level: usize = 1;
                    while (nesting_level > 0) {
                        const peeked = reader.takeByte() catch |err| switch (err) {
                            error.EndOfStream => return error.UnterminatedComment,
                            else => return err,
                        };

                        if (peeked == '*' and try match(reader, '/')) {
                            reader.toss(1);
                            column += 1;
                            nesting_level -= 1;
                        } else if (peeked == '/' and try match(reader, '*')) {
                            reader.toss(1);
                            column += 1;
                            nesting_level += 1;
                        }

                        if (peeked == '\n') {
                            column = 1;
                            line += 1;
                        } else {
                            column += 1;
                        }
                    }
                    break :blk null;
                } else {
                    break :blk .{ .type = .SLASH, .lexeme = "/" };
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
                const lexeme = try std.fmt.allocPrint(allocator, "\"{s}\"", .{owned_string});
                break :blk .{ .type = .STRING, .literal = .{ .string = owned_string }, .lexeme = lexeme };
            },
            else => blk: {
                if (isDigit(byte)) {
                    const result = try number(allocator, reader, byte);
                    column += result.col_offset;
                    break :blk result.token;
                } else if (isAlpha(byte)) {
                    const result = try identifier(allocator, reader, byte);
                    column += result.col_offset;
                    break :blk result.token;
                } else {
                    return error.UnexpectedCharacter;
                }
            },
        };

        if (token == null) continue;

        token.?.line = start_line;
        token.?.column = start_column;
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

fn isDigit(char: u8) bool {
    return char >= '0' and char <= '9';
}

fn number(allocator: std.mem.Allocator, reader: *std.Io.Reader, byte: u8) !struct { token: Token, col_offset: usize } {
    var column: usize = 0;
    var string: [64]u8 = undefined;
    string[0] = byte;

    var i: usize = 1;
    while (true) {
        const char = reader.peekByte() catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };

        if (!isDigit(char)) break;

        string[i] = char;
        reader.toss(1);
        column += 1;
        i += 1;
    }

    var result = std.fmt.parseFloat(f64, string[0..i]) catch return error.UnexpectedCharacter;

    const decimal_point = reader.peek(2) catch |err| switch (err) {
        error.EndOfStream => {
            return .{
                .token = .{
                    .type = .NUMBER,
                    .literal = .{ .number = result },
                    .lexeme = try allocator.dupe(u8, string[0..i]),
                },
                .col_offset = column,
            };
        },
        else => return err,
    };

    if (decimal_point[0] == '.' and isDigit(decimal_point[1])) {
        reader.toss(1);

        string[i] = decimal_point[0];
        i += 1;
        column += 1;

        string[i] = decimal_point[1];
        while (true) {
            const char = reader.peekByte() catch |err| switch (err) {
                error.EndOfStream => break,
                else => return err,
            };

            if (!isDigit(char)) break;

            string[i] = char;
            reader.toss(1);
            column += 1;
            i += 1;
        }
    }

    result = std.fmt.parseFloat(f64, string[0..i]) catch return error.UnexpectedCharacter;
    return .{
        .token = .{
            .type = .NUMBER,
            .literal = .{ .number = result },
            .lexeme = try allocator.dupe(u8, string[0..i]),
        },
        .col_offset = column,
    };
}

fn isAlpha(byte: u8) bool {
    return (byte >= 'a' and byte <= 'z') or
        (byte >= 'A' and byte <= 'Z') or
        (byte == '_');
}

fn identifier(allocator: std.mem.Allocator, reader: *std.Io.Reader, byte: u8) !struct { token: Token, col_offset: usize } {
    var column: usize = 0;
    var string: [256]u8 = undefined;
    var i: usize = 0;
    string[i] = byte;
    i += 1;
    while (true) {
        const char = reader.peekByte() catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };

        if (!(isAlpha(char) or isDigit(char))) break;

        string[i] = char;
        reader.toss(1);
        column += 1;
        i += 1;
    }

    const lexeme = try allocator.dupe(u8, string[0..i]);
    const token_type = keywords.get(lexeme);

    return .{ .token = .{
        .type = if (token_type) |t| t else .IDENTIFIER,
        .lexeme = lexeme,
    }, .col_offset = column };
}
