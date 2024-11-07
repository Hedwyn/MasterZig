const std = @import("std");

const StrError = error{
    DestinationTooSmall,
};

pub fn copy_null_terminated(from: [:0]const u8, to: []u8) StrError!void {
    for (0.., from) |i, char| {
        if (i == to.len) {
            return StrError.DestinationTooSmall;
        }
        to[i] = from[i];
        if (char == 0) {
            return;
        }
    }
}

test "copy string bigger destination" {
    const from = "Hello World!";
    var to: [20]u8 = undefined;
    try copy_null_terminated(from, &to);
    try std.testing.expectStringStartsWith(&to, from);
    try std.testing.expectEqual(0, to[from.len - 1]);
}

test "copy string same size" {
    const from = "Hello World!";
    var to: [from.len]u8 = undefined;

    try copy_null_terminated(from, &to);
    try std.testing.expectEqualStrings(from, &to);
}

test "copy string smaller destination" {
    const from = "Hello World!";
    var to: [from.len - 1]u8 = undefined;
    try std.testing.expectError( //
        StrError.DestinationTooSmall, //
        copy_null_terminated(from, &to));
}
