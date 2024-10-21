const std = @import("std");
const testing = std.testing;

// Default parameters
const default_row_width = 5;
const default_row_count = 12;
const default_color_count = 8;
const default_game_size = default_row_count * default_row_width;

pub const MastermindError = error{
    OutOfBoundRowIdx,
    InvalidColor,
    GameLost,
};

/// A container for all settings required for the game
pub const GameParameters = struct {
    row_width: usize = default_row_width,
    row_count: usize = default_row_count,
    color_count: usize = default_color_count,

    pub fn get_total_size(self: GameParameters) usize {
        return self.row_count * self.row_width;
    }
};

pub const RowScore = struct {
    correct_color: u32 = 0,
    correct_token: u32 = 0,
};

pub fn get_row_structure(color_count: comptime_int, width: comptime_int) type {
    return struct {
        value: u64 = 0,
        comptime color_count: usize = color_count,
        comptime width: usize = width,

        const Self = @This();

        pub fn new() Self {
            return Self{ .value = 0 };
        }

        pub fn set_cell(self: *Self, cell_index: usize, color: u64) MastermindError!void {
            // sanity checks
            if (cell_index >= self.width) {
                return MastermindError.OutOfBoundRowIdx;
            }
            if (color > (1 << self.color_count)) {
                return MastermindError.InvalidColor;
            }
            // applying bit shift to place color in the correct column
            self.value |= color << @truncate(cell_index * self.color_count);
        }

        pub fn evaluate(self: Self, secret: Self) RowScore {
            var correct_color: u8 = 0;
            var correct_token: u8 = 0;
            var value = self.value;
            inline for (0..self.color_count) |shift| {
                const mask = secret.value & value;
                // A token is correct if its equal to the secret without shifting
                if (shift == 0) {
                    correct_color += @popCount(mask);
                }
                // After a shift, getting a match means the color is present but
                // the position is wrong
                else {
                    correct_token += @popCount(mask);
                }
                // clearing the tokens that were matching as we consumed them
                value ^= mask;
            }
            return .{ .correct_color = correct_color, .correct_token = correct_token };
        }
    };
}

pub const Row = get_row_structure(default_color_count, default_row_width);

pub const default_game_params = GameParameters{};

pub const GameBoard = struct {
    cells: []Row,
    current_row: usize = 0,

    comptime params: *const GameParameters = &default_game_params,

    pub fn create(allocator: *const std.mem.Allocator, comptime params: ?*GameParameters) !*GameBoard {
        const game_params = params orelse &default_game_params;
        const board_size = game_params.get_total_size();
        const cells = try allocator.alloc(Row, board_size);
        const new_board = try allocator.create(GameBoard);
        for (cells) |*cell| {
            cell.* = .{ .value = 0 };
        }
        new_board.* = GameBoard{
            .cells = cells,
            .params = game_params,
        };
        return new_board;
    }
    pub fn destroy(self: *GameBoard, allocator: *const std.mem.Allocator) void {
        allocator.destroy(self.cells);
        allocator.destroy(self);
    }

    pub fn set_cell_at_row(self: *GameBoard, row_index: usize, column_index: usize, color: u32) MastermindError!void {
        try self.cells[row_index].set_cell(column_index, color);
    }

    pub fn set_cell(self: *GameBoard, column_index: usize, color: u32) MastermindError!void {
        return try self.set_cell_at_row(self.current_row, column_index, color);
    }

    pub fn is_lost(self: *GameBoard) bool {
        return self.current_row >= self.params.row_count;
    }

    /// Flags the row as validated by the player, i.e., row is ready for evaluation
    pub fn validate_current_row(self: *GameBoard) MastermindError!void {
        if (self.is_lost()) {
            return .GameLost;
        }
        self.current_row += 1;
    }

    pub inline fn get_secret(self: *GameBoard) Row {
        return self.cells[0];
    }
    pub fn evaluate_row(self: *GameBoard, row_index: ?usize) *RowScore {
        return self.cells[row_index].evaluate(self.get_secret());
    }
};

pub fn get_color_set(comptime color_count: comptime_int) [color_count]u64 {
    var colors: [color_count]u64 = undefined;
    comptime std.debug.assert(color_count < 64);
    for (0..color_count) |i| {
        colors[i] = @as(u64, 1) << @truncate(i);
    }
    return colors;
}

test "set row color" {
    const colors = get_color_set(8);
    var row = Row.new();
    for (0..default_row_width) |i| {
        try row.set_cell(i, colors[i]);
    }
    try testing.expectEqual(colors[0], 0x1);
    try testing.expectEqual(colors[1], 0x2);
    try testing.expectEqual(row.value, 0x1008040201);
}

test "evaluate row" {
    const colors = get_color_set(8);
    var row = Row.new();

    for (0..default_row_width) |i| {
        try row.set_cell(i, colors[i]);
    }
    const result = row.evaluate(row);
    try std.testing.expectEqual(5, result.correct_color);
    try std.testing.expectEqual(0, result.correct_token);
}

test "init game" {
    var cells = [_]Row{.{ .value = 0 }} ** default_game_size;
    const board = GameBoard{ .cells = &cells };
    _ = board;
}

test "alloc game board" {
    const allocator = std.heap.page_allocator;
    const board = try GameBoard.create(&allocator, null);
    _ = board;
}
