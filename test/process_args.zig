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

    const output_string = try std.mem.join(allocator, "\n", process_output.output_lines);
    defer allocator.free(output_string);
    const expected_string =
        \\
        \\Output from stderr:
        \\arg 0: ./zig-out/bin/bin_for_testing__process_args.exe
        \\arg 1: ping
        \\
    ;

    try std.testing.expect(std.mem.eql(u8, output_string, expected_string));
}
