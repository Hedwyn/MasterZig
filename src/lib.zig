const engine = @import("engine.zig");
const std = @import("std");

test "show_params" {
    const params = engine.GameParameters{};
    std.debug.print("Default Parameters: {}", .{params});
}
