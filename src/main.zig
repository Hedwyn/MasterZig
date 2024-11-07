const std = @import("std");
const cli = @import("frontends/cli.zig");
const utils = @import("utils.zig");

const ArgIterator = std.process.ArgIterator;
const assert = std.debug.assert;

const StrError = error{
    DestinationTooSmall,
};

const CmdLineError = error{
    EmptyFlag,
    MissingValue,
    InvalidFlag,
    UnknownFlag,
    UnknownArgument,
    FlagTooLong,
    ValueTooLong,
};

const max_filename_length = 50;
const log_level_max_size = 10;

const CliArgs = struct {
    replay_file: [max_filename_length]u8 = [_]u8{0} ** max_filename_length,
    log_level: [log_level_max_size]u8 = [_]u8{0} ** log_level_max_size,

    pub fn parse(args: *ArgIterator) CmdLineError!CliArgs {
        // process name
        const first = args.next() orelse unreachable;
        std.log.debug("Processing arg {s}", .{first});

        var cli_args: CliArgs = undefined;
        var arg_ptr: ?[]u8 = &(cli_args.replay_file);

        while (args.next()) |current_arg| {
            std.log.debug("Processing arg {s}", .{current_arg});

            if (current_arg.len < 2) {
                return CmdLineError.EmptyFlag;
            }
            if (current_arg[0] != '-') {
                const ptr = arg_ptr orelse return CmdLineError.UnknownArgument;
                utils.copy_null_terminated(current_arg[1..], ptr) catch {
                    return CmdLineError.ValueTooLong;
                };
                // consuming arg pointer
                arg_ptr = null;
                continue;
            }
            const flag = current_arg[1];
            arg_ptr = switch (flag) {
                'r' => &cli_args.replay_file,
                'l' => &cli_args.log_level,
                else => {
                    std.debug.print("Got flag {c}\n", .{flag});
                    return CmdLineError.UnknownFlag;
                },
            };
        }
        return cli_args;
    }
};

pub fn main() !void {
    var args = std.process.args();
    // First arg is exe name
    // _ = args.next();
    // const fname: ?[]const u8 = args.next();
    const cmd_args = try CliArgs.parse(&args);
    // const from_file = fname orelse null;

    // const replay_file = if (cmd_args.replay_file[0] != 0) cmd_args.replay_file else null;
    std.debug.print("Cmd args are {s}, {s}", .{ cmd_args.replay_file, cmd_args.log_level });
    try cli.play(null);
}
