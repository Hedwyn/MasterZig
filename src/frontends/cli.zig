//! A game frontend that can run in the terminal

const engine = @import("../engine.zig");
const std = @import("std");
const File = std.fs.File;
const Writer = File.Writer;
const Reader = File.Reader;

const assert = std.debug.assert;
const _base_color_set: [8]u64 = engine.get_color_set(8);

pub const CliError = error{
    InvalidColor,
    LineTooLong,
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

    pub fn to_str(self: Color) []const u8 {
        return switch (self) {
            .red => "R",
            .green => "G",
            .blue => "B",
            .yellow => "Y",
            .brown => "W",
            .pink => "P",
            .turquoise => "T",
            .orange => "O",
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

    pub fn read(self: *Console) CliError![buffer_len]u8 {
        const input_len = self.reader.read(&self.buffer) catch unreachable;
        if (input_len == buffer_len) {
            self.flush_input() catch unreachable;
            return CliError.LineTooLong;
        }
        return self.buffer;
    }
};

pub const GameRunner = struct {
    console: *Console,
    board: *engine.GameBoard,

    pub fn set_secret(self: *GameRunner) GameError!void {
        assert(self.board.current_row == 0);
        self.console.write("Input your secret here:\n");
        const player_input = try self.console.read();
        try self.process_user_input(player_input);
        self.console.write("Secret saved !");
    }

    pub fn show_last_row(self: *GameRunner) void {
        const raw_colors = self.board.get_last_row();
        std.log.debug("raw_colors {any}", .{raw_colors});

        for (raw_colors) |color_value| {
            std.log.debug("Converting value 0x{x} to enum", .{color_value});
            const color: Color = @enumFromInt(color_value);
            const repr = color.to_str();
            self.console.write(repr);
        }
        self.console.write("\n");
    }
    pub fn play_next(self: *GameRunner) GameError!void {
        const player_input = try self.console.read();
        try self.process_user_input(player_input);
        const score = self.board.evaluate_last();
        self.console.print("Your score: {}", .{score});
    }

    pub fn process_user_input(self: *GameRunner, input: [buffer_len]u8) GameError!void {
        for (0.., input) |idx, char| {
            // TODO: switch to null-terminated string
            if (char == '\n') {
                break;
            }
            if (idx >= self.board.params.row_width) {
                return GameError.LineTooLong;
            }
            const color = try Color.from_str(char);
            try self.board.set_cell(idx, @intFromEnum(color));
        }
        self.board.current_row += 1;
    }
};

pub fn play() !void {
    var console = Console.create();
    const allocator = std.heap.page_allocator;
    var board = try engine.GameBoard.create(&allocator, null);
    defer board.destroy(&allocator);
    std.log.debug("Color values: {any}", .{_base_color_set});
    var runner = GameRunner{ .console = &console, .board = board };
    console.write("Starting MasterZig !\n");

    // TODO: set secret with random data
    try runner.set_secret();
    console.write("Your secret is:\n");
    runner.show_last_row();
    // Revealing secret for debugging
    for (0..12) |_| {
        console.write("Play your next turn !\n");
        try runner.play_next();
        console.write("You played:\n");
        runner.show_last_row();
    }
}
