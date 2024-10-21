const std = @import("std");
const cli = @import("frontends/cli.zig");

pub fn main() !void {
    try cli.play();
}
