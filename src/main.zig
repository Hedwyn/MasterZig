const std = @import("std");
const cli = @import("frontends/cli.zig");
const utils = @import("utils.zig");
const log = @import("log.zig");

const masterzig_log = log.masterzig_log;
const ArgIterator = std.process.ArgIterator;
const assert = std.debug.assert;
const LoggingLevel = std.log.Level;

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
    InvalidLogLevel,
};

const max_filename_length = 50;
const log_level_max_size = 10;

const default_logging_level = "warning";

pub fn check_logging_level(logging_level: []u8) CmdLineError!LoggingLevel {
    inline for (std.meta.fields(LoggingLevel)) |field| {
        const level: LoggingLevel = @enumFromInt(field.value);
        if (std.mem.eql(
            u8,
            level.asText(),
            logging_level,
        )) {
            return level;
        }
    }
    return CmdLineError.InvalidLogLevel;
}

const CliArgs = struct {
    replay_file: ?[:0]u8 = null,
    log_level: LoggingLevel = LoggingLevel.warn,

    pub fn parse(args: *ArgIterator) CmdLineError!CliArgs {
        // process name
        const first = args.next() orelse unreachable;
        masterzig_log.debug("Processing arg {s}", .{first});
        var replay_file: ?[:0]u8 = null;
        var log_level_name: ?[:0]u8 = null;
        var arg_ptr: ?*?[:0]u8 = null;

        while (args.next()) |current_arg| {
            masterzig_log.debug("Processing arg {s}", .{current_arg});

            if (current_arg.len < 2) {
                return CmdLineError.EmptyFlag;
            }
            if (current_arg[0] != '-') {
                const ptr = arg_ptr orelse return CmdLineError.UnknownArgument;
                // utils.copy_null_terminated(current_arg[1..], ptr) catch {
                //     return CmdLineError.ValueTooLong;
                // };
                ptr.* = @constCast(current_arg);
                // consuming arg pointer
                arg_ptr = null;
                continue;
            }
            const flag = current_arg[1];
            arg_ptr = switch (flag) {
                'r' => &replay_file,
                'l' => &log_level_name,
                else => {
                    std.debug.print("Got flag {c}\n", .{flag});
                    return CmdLineError.UnknownFlag;
                },
            };
        }
        if (log_level_name) |level_name| {
            return .{
                .replay_file = replay_file,
                .log_level = try check_logging_level(level_name),
            };
        }
        return CliArgs{
            .replay_file = replay_file,
        };
    }
};

pub fn main() !void {
    masterzig_log.debug("Hi !", .{});
    var args = std.process.args();
    // First arg is exe name
    // _ = args.next();
    // const fname: ?[]const u8 = args.next();
    const cmd_args = try CliArgs.parse(&args);
    // const from_file = fname orelse null;

    // const replay_file = if (cmd_args.replay_file[0] != 0) cmd_args.replay_file else null;
    std.debug.print("Cmd args are {?s}, {}", .{ cmd_args.replay_file, cmd_args.log_level });
    try cli.play(null);
}
