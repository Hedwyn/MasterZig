const std = @import("std");
const engine = @import("engine.zig");
const cli = @import("frontends/cli.zig");

test "show_params" {
    const params = engine.GameParameters{};
    std.debug.print("Default Parameters: {}", .{params});
}
