//! A game frontend that can run in the terminal

const engine = @import("../engine.zig");
const std = @import("std");
const bufPrint = std.fmt.bufPrint;
const File = std.fs.File;
const Writer = File.Writer;
const Reader = File.Reader;

const assert = std.debug.assert;
const _base_color_set: [8]u64 = engine.get_color_set(8);

// terminal color
const esc = "\u{001b}";
const default_background = esc ++ "[40m";
const board_background = esc ++ "[48;5;130m";
const default_color = esc ++ "[37m";

pub const CliError = error{
    InvalidColor,
    LineTooLong,
    LineTooShort,
};

const GameError = CliError || engine.MastermindError;

pub const Color = enum(u32) {
    red = _base_color_set[0],
    green = _base_color_set[1],
    blue = _base_color_set[2],
    yellow = _base_color_set[3],
    brown = _base_color_set[4],
    pink = _base_color_set[5],
    turquoise = _base_color_set[6],
    orange = _base_color_set[7],

    pub fn colorize(_: Color, color_index: comptime_int, comptime content: []const u8) []const u8 {
        assert(color_index >= 0);
        assert(color_index < 256);
        comptime var color_buf: [3]u8 = undefined;
        const color_code = comptime std.fmt.bufPrint(&color_buf, "{}", .{color_index}) catch unreachable;
        return esc ++ "[38;5;" ++ color_code ++ "m" ++ content ++ default_color;
    }

    pub fn to_str(self: Color) []const u8 {
        return switch (self) {
            .red => self.colorize(160, "R"),
            .green => "\u{001b}[32mG\u{001b}[37m",
            .blue => "\u{001b}[34mB\u{001b}[37m",
            .yellow => "\u{001b}[33mG\u{001b}[37m",
            .brown => "\u{001b}[36mG\u{001b}[37m",
            .pink => "\u{001b}[38;5;165mP\u{001b}[37m",
            .turquoise => "\u{001b}[38;5;122mT\u{001b}[37m",
            .orange => "\u{001b}[38;5;209mO\u{001b}[37m",
        };
    }

    pub fn from_str(char: u8) CliError!Color {
        return switch (char) {
            'R' => .red,
            'G' => .green,
            'B' => .blue,
            'Y' => .yellow,
            'W' => .brown,
            'P' => .pink,
            'T' => .turquoise,
            'O' => .orange,
            else => CliError.InvalidColor,
        };
    }
};

const buffer_len = 20;

pub const Console = struct {
    writer: Writer,
    reader: Reader,
    buffer: [buffer_len]u8 = undefined,

    pub fn create() Console {
        return .{
            .writer = std.io.getStdOut().writer(), //
            .reader = std.io.getStdIn().reader(),
        };
    }

    pub fn write(self: *Console, bytes: []const u8) void {
        _ = self.writer.write(bytes) catch unreachable;
    }

    pub fn print(self: *Console, comptime fmt: []const u8, args: anytype) void {
        _ = self.writer.print(fmt, args) catch unreachable;
    }

    pub fn flush_input(self: *Console) !void {
        while (try self.reader.readByte() != '\n') {}
    }

    pub fn read(self: *Console, len: usize) CliError![buffer_len]u8 {
        assert(len < buffer_len);
        for (0..len + 1) |i| {
            self.buffer[i] = self.reader.readByte() catch {
                return CliError.LineTooShort;
            };
        }
        if (self.buffer[len] != '\n') {
            self.flush_input() catch unreachable;
            return CliError.LineTooLong;
        }
        return self.buffer;
    }

    pub fn readToBuffer(self: *Console, buffer: []u8) !void {
        _ = self.reader.readAtLeast(buffer, buffer.len) catch {
            return CliError.LineTooShort;
        };
        const termination = self.reader.readByte() catch {
            return CliError.LineTooLong;
        };
        if (termination != '\n') {
            return CliError.LineTooLong;
        }
    }
};

pub fn GameRunner(parameters: engine.GameParameters) type {
    return struct {
        console: *Console,
        board: *engine.GameBoard(parameters),
        const params: engine.GameParameters = parameters;
        const Self = @This();

        pub fn process_user_input(input: [params.row_width]u8) GameError![params.row_width]u64 {
            var colors: [params.row_width]u64 = undefined;
            for (0.., input) |i, char| {
                colors[i] = @intFromEnum(try Color.from_str(char));
            }
            return colors;
        }

        pub fn set_secret(self: *Self) GameError!void {
            assert(self.board.current_row == 0);
            var player_input: [params.row_width]u8 = undefined;
            self.console.write("Input your secret here:\n");
            try self.console.readToBuffer(&player_input);
            std.log.debug("Input echo: {s}", .{player_input});
            try self.board.play_next_move(try process_user_input(player_input));
            self.console.write("Secret saved !\n");
            self.show_last_row();
        }

        pub fn show_row(self: *Self, index: usize) void {
            self.console.write(board_background);
            defer self.console.write("\n");
            defer self.console.write(default_background);
            const raw_colors = self.board.get_row(index);
            for (raw_colors) |color_value| {
                const color: Color = @enumFromInt(color_value);
                const repr = color.to_str();
                self.console.write(repr);
            }
            // Adding a space to separate scores
            self.console.write(" ");
            var token_ctr: usize = 0;
            const score = self.board.evaluate_row(index);
            for (0..score.correct_token) |_| {
                self.console.write("\u{001b}[37mW\u{001b}[37m");
                token_ctr += 1;
            }
            for (0..score.correct_color) |_| {
                self.console.write("\u{001b}[30mB\u{001b}[37m");
                token_ctr += 1;
            }

            for (token_ctr..params.row_width) |_| {
                self.console.write(" ");
            }
        }

        pub fn show_last_row(self: *Self) void {
            self.show_row(self.board.current_row - 1);
        }

        pub fn show_all_rows(self: *Self) void {
            for (1..self.board.current_row) |i| {
                self.show_row(i);
            }
        }

        pub fn play_next(self: *Self) GameError!bool {
            var player_input: [params.row_width]u8 = undefined;
            try self.console.readToBuffer(&player_input);
            std.log.debug("Input echo: {s}", .{player_input});
            try self.board.play_next_move(try process_user_input((player_input)));
            const score = self.board.evaluate_last();
            self.console.print("Your score: {}\n", .{score});
            // Is it won ?
            return (score.correct_color == params.row_width);
        }
    };
}

pub fn play(from_file: ?[]const u8) !void {
    var console: Console = undefined;
    if (from_file == null) {
        console = Console.create();
    } else {
        const file = try std.fs.cwd().openFile(from_file orelse unreachable, .{});
        const reader = file.reader();
        console = Console{
            .reader = reader, //
            .writer = std.io.getStdOut().writer(),
        };
    }

    const allocator = std.heap.page_allocator;
    var board = try engine.GameBoard(engine.default_game_params).create(&allocator);
    defer board.destroy(&allocator);
    std.log.debug("Color values: {any}", .{_base_color_set});
    var runner = GameRunner(engine.default_game_params){
        .console = &console, //
        .board = board,
    };
    console.write("Starting MasterZig !\n");

    // TODO: set secret with random data
    try runner.set_secret();
    console.write("Your secret is:\n");
    runner.show_last_row();
    // Revealing secret for debugging
    for (0..3) |_| {
        console.write("\nPlay your next turn !\n");
        if (try runner.play_next()) {
            console.write("Congratulations, you won !\n");
            return;
        }
        std.log.debug("Tour {}", .{board.current_row});
        console.write("Current board: \n\n");
        runner.show_all_rows();
    }
}
