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
    EmptyRow,
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

pub fn getRowStructure(color_count: comptime_int, width: comptime_int) type {
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

        inline fn _get_cell(self: *Row, cell_index: usize) u64 {
            const shift: u6 = @truncate(cell_index * color_count);
            const mask: u64 = (1 << color_count) - 1;
            const shifted_mask = mask << shift;
            const masked = self.value & shifted_mask;
            return (masked >> shift);
        }

        pub fn get_cell(self: *Row, cell_index: usize) MastermindError!u64 {
            if (cell_index >= width) {
                return MastermindError.OutOfBoundRowIdx;
            }
            return self._get_cell(cell_index);
        }

        pub fn get_all(self: *Row) [width]u64 {
            var colors: [width]u64 = undefined;
            for (0..width) |i| {
                colors[i] = self._get_cell(i);
            }
            return colors;
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

pub const Row = getRowStructure(default_color_count, default_row_width);

pub const default_game_params = GameParameters{};

pub fn GameBoard(comptime parameters: GameParameters) type {
    return struct {
        cells: []Row = undefined,
        current_row: usize = 0,
        const params: GameParameters = parameters;
        const Self = @This();

        pub fn create(allocator: *const std.mem.Allocator) !*Self {
            const game_params = params;
            const board_size = game_params.get_total_size();
            const cells = try allocator.alloc(Row, board_size);
            const new_board = try allocator.create(Self);
            for (cells) |*cell| {
                cell.* = .{ .value = 0 };
            }
            new_board.* = Self{
                .cells = cells,
            };
            return new_board;
        }
        pub fn destroy(self: *Self, allocator: *const std.mem.Allocator) void {
            allocator.destroy(&self.cells);
            allocator.destroy(self);
        }

        pub fn set_cell_at_row(self: *Self, row_index: usize, column_index: usize, color: u64) MastermindError!void {
            try self.cells[row_index].set_cell(column_index, color);
        }

        pub fn set_cell(self: *Self, column_index: usize, color: u64) MastermindError!void {
            return try self.set_cell_at_row(self.current_row, column_index, color);
        }

        pub fn get_row(self: *Self, row_index: ?usize) [params.row_width]u64 {
            return self.cells[row_index orelse self.current_row].get_all();
        }

        pub fn get_last_row(self: *Self) [params.row_width]u64 {
            return self.get_row(null);
        }

        pub fn set_row(self: *Self, row_index: usize, row: [params.row_width]u64) void {
            for (0..self.params.row_width) |i| {
                self.set_cell_at_row(row_index, i, row[i]);
            }
        }

        pub fn play_next_move(self: *Self, row: [params.row_width]u64) void {
            self.set_row(self.current_row, row);
            self.current_row += 1;
        }

        pub fn is_lost(self: *Self) bool {
            return self.current_row >= self.params.row_count;
        }

        /// Flags the row as validated by the player, i.e., row is ready for evaluation
        pub fn validate_current_row(self: *Self) MastermindError!void {
            if (self.is_lost()) {
                return .GameLost;
            }
            self.current_row += 1;
        }

        pub inline fn get_secret(self: *Self) Row {
            return self.cells[0];
        }

        pub fn evaluate_row(self: *Self, row_index: ?usize) RowScore {
            return self.cells[row_index orelse self.current_row].evaluate(self.get_secret());
        }

        pub fn evaluate_last(self: *Self) RowScore {
            return self.cells[self.current_row].evaluate(self.get_secret());
        }
    };
}

const TestGameBoard = GameBoard(default_game_params);

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

test "get cell color" {
    const colors = get_color_set(8);
    var row = Row.new();
    for (0..default_row_width) |i| {
        try row.set_cell(i, colors[i]);
    }
    for (0..default_row_width) |i| {
        try testing.expectEqual(colors[i], row.get_cell(i));
    }
}

test "get all colors" {
    const colors = get_color_set(8);
    var row = Row.new();
    for (0..default_row_width) |i| {
        try row.set_cell(i, colors[i]);
    }
    const obtained_colors = row.get_all();
    for (0..default_row_width) |i| {
        try testing.expectEqual(colors[i], obtained_colors[i]);
    }
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
    const board = TestGameBoard{ .cells = &cells };
    _ = board;
}

test "alloc game board" {
    const allocator = std.heap.page_allocator;
    const board = try TestGameBoard.create(&allocator);
    defer board.destroy(&allocator);
}

test "evaluate last" {
    const colors = get_color_set(8);
    const allocator = std.heap.page_allocator;
    var board = try TestGameBoard.create(&allocator);

    for (0..default_row_width) |i| {
        try board.set_cell(i, colors[i]);
    }
    const result = board.evaluate_last();
    try std.testing.expectEqual(5, result.correct_color);
    try std.testing.expectEqual(0, result.correct_token);
    try std.testing.expectEqual(board.evaluate_row(0), result);
}
