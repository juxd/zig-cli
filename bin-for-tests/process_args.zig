const std = @import("std");
const allocator = std.testing.allocator;

pub fn main() !void {
    var arg_iterator = std.process.argsWithAllocator(allocator);
    defer arg_iterator.deinit();

    var i: u8 = 0;
    while (arg_iterator.next(allocator)) |arg| {
        _ = arg catch |err| {
            return err;
        };
        std.debug.print("arg {d}: {s}\n", .{ i, arg });
        i += 1;
    }
}
