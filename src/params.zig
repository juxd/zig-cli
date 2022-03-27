const std = @import("std");
const testing = std.testing;
const args = @import("args.zig");

pub fn Flag(comptime T: type) type {
    return struct {
        flag: []const u8,
        parse_instruction: args.ParseInstruction(T),
    };
}

pub fn Anon(comptime T: type) type {
    return struct {
        parse_instruction: args.ParseInstruction(T),
    };
}

pub fn Param(comptime T: type) type {
    return union(enum) {
        flag: Flag(T),
        anon: Anon(T),
    };
}
