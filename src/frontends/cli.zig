//! A game frontend that can run in the terminal

const engine = @import("../engine.zig");
const std = @import("std");
const File = std.fs.File;
const Writer = File.Writer;
const Reader = File.Reader;

const _base_color_set: [8]u64 = engine.get_color_set(8);

pub const CliError = error{
    LineTooLong,
};

pub const Color = enum(u64) {
    red = _base_color_set[0],
    green = _base_color_set[1],
    blue = _base_color_set[2],
    yellow = _base_color_set[3],
    brown = _base_color_set[4],
    pink = _base_color_set[5],
    gray = _base_color_set[6],
    orange = _base_color_set[7],

    pub fn toStr(self: Color) []const u8 {
        return switch (self) {
            .red => "R",
            .green => "G",
            .blue => "B",
            .yellow => "Y",
            .brown => "W",
            .pink => "P",
            .gray => "G",
            .orange => "O",
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

    pub fn flush_input(self: *Console) !void {
        // while (try self.reader.readAll(&self.buffer) > 0) {}
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

pub const GameRenderer = struct {
    console: *Console,
    board: *engine.GameBoard,
};

pub fn play() !void {
    var console = Console.create();
    console.write("Starting MasterZig !\n");
    const allocator = std.heap.page_allocator;
    const board = try engine.GameBoard.create(&allocator, null);
    defer allocator.destroy(board);

    for (0..3) |_| {
        const user_input = console.read() catch {
            std.debug.print("Line is too long !\n", .{});
            continue;
        };
        std.debug.print("User input is: {s}", .{user_input});
    }
}
