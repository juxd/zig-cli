const std = @import("std");
const SplitIterator = std.mem.SplitIterator;

pub const ProcessOutput = struct {
    exit_code: u8,
    allocator: *std.mem.Allocator,
    output_lines: []const []const u8,
    stderr: []const u8,
    stdout: []const u8,

    pub fn runAndCollectOutput(exe_file_path: []const u8, args: []const []const u8, allocator: *std.mem.Allocator) !ProcessOutput {
        var argv = std.ArrayList([]const u8).init(allocator);
        defer argv.deinit();
        try argv.append(exe_file_path);
        for (args) |arg| {
            try argv.append(arg);
        }

        const child = std.ChildProcess.init(argv.items, allocator) catch unreachable;
        defer child.deinit();

        child.stdin_behavior = .Pipe;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        child.spawn() catch |err| {
            var buf: [100]u8 = undefined;
            const cwd = try std.os.getcwd(&buf);
            std.debug.print("Unable to spawn child process, path: {s}, cwd: {s}, err: {any}\n", .{ exe_file_path, cwd, err });
            return err;
        };

        // Allow up to 1 MB of stdout capture
        const max_output_len = 1 * 1024 * 1024;

        const stdout: []const u8 = try child.stdout.?.reader().readAllAlloc(allocator, max_output_len);
        var stdout_iterator = std.mem.split(u8, stdout, "\n");
        const stderr: []const u8 = try child.stderr.?.reader().readAllAlloc(allocator, max_output_len);
        var stderr_iterator = std.mem.split(u8, stderr, "\n");

        var output_lines = std.ArrayList([]const u8).init(allocator);
        defer output_lines.deinit();
        try collectIteratorIntoArrayList(u8, &output_lines, &stdout_iterator);
        try output_lines.append("Output from stderr:");
        try collectIteratorIntoArrayList(u8, &output_lines, &stderr_iterator);

        const term = child.wait() catch |err| {
            std.debug.print("Unable to wait for child process {}", .{.{
                .child_info = .child_info,
                .err = err,
            }});
            return err;
        };
        switch (term) {
            .Exited => |exit_code| {
                return ProcessOutput{
                    .allocator = allocator,
                    .exit_code = exit_code,
                    .output_lines = output_lines.toOwnedSlice(),
                    .stderr = stderr,
                    .stdout = stdout,
                };
            },
            else => {
                std.debug.print("{s} terminated unexpectedly\n", .{exe_file_path});
                return error.UnexpectedTermination;
            },
        }
    }

    fn collectIteratorIntoArrayList(comptime T: type, array_list: *std.ArrayList([]const T), iterator: *SplitIterator(T)) !void {
        while (iterator.next()) |t| {
            try array_list.append(t);
        }
    }

    pub fn deinit(self: ProcessOutput) void {
        self.allocator.free(self.output_lines);
        self.allocator.free(self.stderr);
        self.allocator.free(self.stdout);
    }
};
