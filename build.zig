const std = @import("std");
const test_service = @import("test_service");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("zilc", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    const main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const bin_for_tests_process_args = b.addExecutable("bin_for_testing__process_args", "bin-for-tests/process_args.zig");
    bin_for_tests_process_args.setBuildMode(.Debug);
    bin_for_tests_process_args.install();

    const test_process_args = b.addTest("test/process_args.zig");
    test_process_args.step.dependOn(b.getInstallStep());

    const test_all_step = b.step("test-all", "Run all tests");
    test_all_step.dependOn(&main_tests.step);
    test_all_step.dependOn(&test_process_args.step);
}
