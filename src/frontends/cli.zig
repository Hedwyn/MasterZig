//! A game frontend that can run in the terminal

const engine = @import("../engine.zig");
const std = @import("std");
const File = std.fs.File;
const Writer = File.Writer;

const _base_color_set: [8]u64 = engine.get_color_set(8);

pub const Colors = enum(u64) {
    red = _base_color_set[0],
    green = _base_color_set[1],
    blue = _base_color_set[2],
    yellow = _base_color_set[3],
    brown = _base_color_set[4],
    pink = _base_color_set[5],
    gray = _base_color_set[6],
    orange = _base_color_set[7],
};

pub const Console = struct {
    writer: Writer,

    pub fn create() Console {
        return .{ .writer = std.io.getStdOut().writer() };
    }

    pub fn write(self: *Console, bytes: []const u8) !void {
        _ = try self.writer.write(bytes);
    }
};

pub fn play() !void {
    var console = Console.create();
    _ = try console.write("Starting MasterZig !\n");
    const allocator = std.heap.page_allocator;
    const board = try engine.GameBoard.create(&allocator, null);
    defer allocator.destroy(board);
}
