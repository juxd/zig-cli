const std = @import("std");
const test_service = @import("test_service.zig");

test "process args" {
    const allocator = std.testing.allocator;
    const args: [1][]const u8 = .{"ping"};
    const args_slice: []const []const u8 = args[0..];
    const process_output = test_service.ProcessOutput.runAndCollectOutput("./zig-out/bin/bin_for_testing__process_args.exe", args_slice, allocator) catch |err| {
        return err;
    };
    defer process_output.deinit();

    var expected_strings_: [3][]const u8 = .{ "Output from stderr:", "Hello world!", "" };
    const expected_strings: [][]const u8 = expected_strings_[0..];

    std.debug.print("{d}\n", .{process_output.output_lines.items.len});
    std.debug.print("{d}\n", .{process_output.output_lines.items.len});
    std.debug.print("{d}\n", .{process_output.output_lines.items.len});
    std.debug.print("{d}\n", .{process_output.output_lines.items.len});
    std.debug.print("{d}\n", .{expected_strings.len});
    std.debug.print("{any}\n", .{@TypeOf(process_output.output_lines.items)});
    std.debug.print("{any}\n", .{@TypeOf(expected_strings)});
    for (expected_strings) |line, idx| {
        std.debug.print("{d}: {d} {s}\n", .{ idx, process_output.output_lines.items.len, line });
        try std.testing.expect(std.mem.eql(u8, process_output.output_lines.items[idx], expected_strings[idx]));
    }
}
