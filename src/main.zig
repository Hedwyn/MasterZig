const std = @import("std");
const cli = @import("frontends/cli.zig");

pub fn main() !void {
    var args_it = std.process.args();
    // First arg is exe name
    _ = args_it.next();
    const user_can_if: ?[]const u8 = args_it.next();
    const from_file = user_can_if orelse null;
    try cli.play(from_file);
}
