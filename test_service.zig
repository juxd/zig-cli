const std = @import("std");
const Builder = std.build.Builder;
const SplitIterator = std.mem.SplitIterator;

pub const ProcessOutput = struct {
    exit_code: u8,
    output: std.ArrayList([]const u8),
};

pub const BuiltTarget = struct {
    builder: *Builder,
    exe_file_path: []const u8,

    pub fn make(builder: *Builder, source_path: []const u8) *@This() {
        self.builder = builder;
    }

    fn collectIteratorIntoArrayList(comptime T: type, array_list: std.ArrayList([]const T), iterator: SplitIterator(T)) void {
        while (iterator.next()) |t| {
            array_list.append(t);
        }
    }

    pub fn runAndCollectOutput(self: *@This(), args: [_][]const u8) !ProcessOutput {
        const builder = self.builder;
        const argv = [_][]const u8{
            self.exe_file_path,
        } ++ args;

        const child = std.ChildProcess.init(&argv, builder.allocator) catch unreachable;
        defer child.deinit();

        child.cwd = builder.build_root;
        child.env_map = builder.env_map;
        child.stdin_behavior = .Pipe;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        const child_info = .{ .cwd = child.cwd, .command = argv };

        child.spawn() catch |err| {
            std.debug.print("Unable to spawn child process {}", .{.{
                .child_info = child_info,
                .err = err,
            }});
        };

        // Allow up to 1 MB of stdout capture
        const max_output_len = 1 * 1024 * 1024;

        const stdout: []const u8 = try child.stdout.?.reader().readAllAlloc(builder.allocator, max_output_len);
        const stdout_iterator = std.mem.split(u8, stdout, "\n");
        const stderr: []const u8 = try child.stderr.?.reader().readAllAlloc(builder.allocator, max_output_len);
        const stderr_iterator = std.mem.split(u8, stderr, "\n");

        const output = std.ArrayList([]const u8).init(builder.allocator);
        collectIteratorIntoArrayList(u8, output, stdout_iterator);
        output.append("Output from stderr:");
        collectIteratorIntoArrayList(u8, output, stderr_iterator);

        const term = child.wait() catch |err| {
            print("Unable to wait for child process {}", .{.{
                .child_info = .child_info,
                .err = err,
            }});
        };

        switch (term) {
            .Exited => |exit_code| {
                return ProcessOutput{ .exit_code, .output };
            },
            else => {
                print("{s}{s} terminated unexpectedly{s}\n", .{ red_text, self.exercise.main_file, reset_text });
                return error.UnexpectedTermination;
            },
        }
    }
};
