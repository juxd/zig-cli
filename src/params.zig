const std = @import("std");
const testing = std.testing;
const Params = @This();

pub fn ArgType(comptime R: type) type {
    return struct {
        fn ParseWith(comptime T: type) type {
            return union(enum) {
                required: fn (str: [:0]const u8, allocator: std.mem.Allocator) T,
                optional: fn (str: [:0]const u8, allocator: std.mem.Allocator) T,
                no_arg,
            };
        }

        pub fn optional(comptime T: type, comptime parse: fn (str: [:0]const u8, allocator: std.mem.Allocator) T) @This() {
            if (R != ?T) {
                @compileError("ArgType.optional(): R must be ?T");
            }
            return @This(){
                .parse_fn = ParseWith(T){ .optional = parse },
            };
        }

        pub fn required(comptime T: type, comptime parse: fn (str: [:0]const u8, allocator: std.mem.Allocator) T) @This() {
            if (R != !T) {
                @compileError("ArgType.optional(): R must be !T");
            }
            return @This(){
                .parse_fn = ParseWith(T){ .required = parse },
            };
        }

        pub fn no_arg() @This() {
            if (R != bool) {
                @compileError("ArgType.no_arg() can only be called with boolean return type.");
            }

            return @This(){
                .parse_fn = ParseWith{.no_arg},
            };
        }
    };
}

pub fn One(comptime T: type) type {
    return struct {
        flag: []const u8,
        arg_type: ArgType(T),
    };
}

fn string_parser(str: [:0]const u8, _: std.mem.Allocator) [:0]const u8 {
    return str;
}

fn int_parser(str: [:0]const u8, _: std.mem.Allocator) u32 {
    return std.fmt.parseInt(u32, str, 10) catch unreachable;
}

test "types work" {
    const string_param = One{
        .flag = "str",
        .arg_type = ArgType.required(),
    };

    const int_param = One{
        .flag = "int",
        .arg_type = ArgType(u32){
            .required = int_parser,
        },
    };

    try testing.expect(string_param.arg_type.toReturnType() == ![:0]const u8);
    try testing.expect(int_param.arg_type.toReturnType() == !u32);
}
