const std = @import("std");
const testing = std.testing;
const param = @import("param.zig");

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "main" {
    testing.refAllDecls(@This());
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}
