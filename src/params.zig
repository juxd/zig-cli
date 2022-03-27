const std = @import("std");
const testing = std.testing;
const Params = @This();

pub const Arg = union(enum) {
    arg: ?[:0]const u8,
    no_arg: bool,
};

pub fn ParseInstruction(comptime R: type) type {
    return struct {
        f: fn (arg: Arg, allocator: *std.mem.Allocator) R,

        pub fn optional(comptime T: type, comptime parse: fn (str: [:0]const u8, allocator: *std.mem.Allocator) T) @This() {
            const F = struct {
                fn f(arg: Arg, allocator: *std.mem.Allocator) R {
                    return switch (arg) {
                        .no_arg => unreachable,
                        .arg => |*arg_| blk: {
                            if (arg_.*) |str| {
                                break :blk parse(str, allocator);
                            }
                            break :blk null;
                        },
                    };
                }
            };

            return @This(){ .f = F.f };
        }

        pub fn required(comptime T: type, comptime parse: fn (str: [:0]const u8, allocator: *std.mem.Allocator) T) @This() {
            const F = struct {
                fn f(arg: Arg, allocator: *std.mem.Allocator) R {
                    return switch (arg) {
                        .no_arg => unreachable,
                        .arg => |*arg_| blk: {
                            const str = arg_.* orelse unreachable;
                            break :blk parse(str, allocator);
                        },
                    };
                }
            };

            return @This(){ .f = F.f };
        }
        pub fn no_arg(comptime T: type, comptime parse: fn (str: [:0]const u8, allocator: *std.mem.Allocator) T) @This() {
            const F = struct {
                fn f(arg: Arg, allocator: *std.mem.Allocator) R {
                    _ = parse;
                    _ = allocator;
                    return switch (arg) {
                        .no_arg => |*no_arg| no_arg.*,
                        .arg => unreachable,
                    };
                }
            };

            return @This(){ .f = F.f };
        }
    };
}

pub fn Flag(comptime R: type) type {
    return struct {
        flag: []const u8,
        arg_type: ParseInstruction(R),
    };
}

fn string_parser(str: [:0]const u8, _: *std.mem.Allocator) [:0]const u8 {
    return str;
}

fn int_parser(str: [:0]const u8, _: *std.mem.Allocator) u32 {
    return std.fmt.parseInt(u32, str, 10) catch unreachable;
}

test "types work" {
    const string_param = Flag([:0]const u8){
        .flag = "string",
        .arg_type = ParseInstruction([:0]const u8).required([:0]const u8, string_parser),
    };

    const int_param = Flag(?u32){
        .flag = "int",
        .arg_type = ParseInstruction(?u32).optional(u32, int_parser),
    };

    try testing.expect(std.mem.eql(u8, string_param.arg_type.f(Arg{ .arg = "hello" }, testing.allocator), "hello"));
    try testing.expect(int_param.arg_type.f(Arg{ .arg = "123" }, testing.allocator) == @as(u32, 123));
    try testing.expect(int_param.arg_type.f(Arg{ .arg = null }, testing.allocator) == null);
}
