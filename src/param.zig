const std = @import("std");
const testing = std.testing;

pub const Arg = union(enum) {
    arg: ?[:0]const u8,
    no_arg: bool,
};

pub fn FlagArg(comptime R: type) type {
    return struct {
        f: fn (arg: Arg, allocator: std.mem.Allocator) R,

        pub fn optional(comptime T: type, comptime parse: fn (str: [:0]const u8, allocator: std.mem.Allocator) T) @This() {
            const F = struct {
                fn f(arg: Arg, allocator: std.mem.Allocator) R {
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

        pub fn required(comptime T: type, comptime parse: fn (str: [:0]const u8, allocator: std.mem.Allocator) T) @This() {
            const F = struct {
                fn f(arg: Arg, allocator: std.mem.Allocator) R {
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

        fn pack(comptime self: @This()) FlagArgPacked {
            return FlagArgPacked{ .flag_arg = self, .typ = R };
        }
    };
}

const FlagArgPacked = struct {
    flag_arg: anytype,
    typ: type,

    fn getType(comptime self: @This()) type {
        return self.typ;
    }

    fn unpack(comptime T: type, comptime self: @This()) FlagArg(T) {
        return self.flag_arg;
    }
};

pub const Anon_ = struct {
    arg: ?[:0]const u8,
};

pub fn AnonArg(comptime R: type) type {
    return struct {
        f: fn (arg: Anon_, allocator: std.mem.Allocator) R,

        pub fn optional(comptime T: type, comptime parse: fn (str: [:0]const u8, allocator: std.mem.Allocator) T) @This() {
            const F = struct {
                fn f(arg: Anon_, allocator: std.mem.Allocator) R {
                    if (arg.arg) |str| {
                        return parse(str, allocator);
                    }
                    return null;
                }
            };

            return @This(){ .f = F.f };
        }

        pub fn required(comptime T: type, comptime parse: fn (str: [:0]const u8, allocator: std.mem.Allocator) T) @This() {
            const F = struct {
                fn f(arg: Anon_, allocator: std.mem.Allocator) R {
                    const str = arg.arg orelse unreachable;
                    return parse(str, allocator);
                }
            };

            return @This(){ .f = F.f };
        }

        fn pack(comptime self: @This()) AnonArgPacked {
            return AnonArgPacked{ .anon_arg = self, .typ = R };
        }
    };
}

const AnonArgPacked = struct {
    anon_arg: anytype,
    typ: type,

    fn getType(comptime self: @This()) type {
        return self.typ;
    }

    fn unpack(comptime T: type, comptime self: @This()) AnonArg(T) {
        return self.anon_arg;
    }
};

fn string_parser(str: [:0]const u8, _: std.mem.Allocator) [:0]const u8 {
    return str;
}

fn int_parser(str: [:0]const u8, _: std.mem.Allocator) u32 {
    return std.fmt.parseInt(u32, str, 10) catch unreachable;
}

const parse_required_string_arg = FlagArg([:0]const u8).required([:0]const u8, string_parser);

const parse_optional_int_arg = FlagArg(?u32).optional(u32, int_parser);

const parse_required_string_anon = AnonArg([:0]const u8).required([:0]const u8, string_parser);

const parse_optional_int_anon = AnonArg(?u32).optional(u32, int_parser);

test "types work" {
    try testing.expect(std.mem.eql(u8, parse_required_string_arg.f(Arg{ .arg = "hello" }, testing.allocator), "hello"));
    try testing.expect(parse_optional_int_arg.f(Arg{ .arg = "123" }, testing.allocator) == @as(u32, 123));
    try testing.expect(parse_optional_int_arg.f(Arg{ .arg = null }, testing.allocator) == null);

    try testing.expect(std.mem.eql(u8, parse_required_string_anon.f(Anon_{ .arg = "world" }, testing.allocator), "world"));
    try testing.expect(parse_optional_int_anon.f(Anon_{ .arg = "456" }, testing.allocator) == @as(u32, 456));
    try testing.expect(parse_optional_int_anon.f(Anon_{ .arg = null }, testing.allocator) == null);
}

fn One(comptime T: type) type {
    return union(enum) {
        arg_flag: Flag,
        no_arg_flag: No_arg,
        anon: Anon,

        const Flag = struct {
            flag: []const u8,
            arg: FlagArg(T),
        };

        const No_arg = struct {
            flag: []const u8,
        };

        const Anon = struct {
            arg: AnonArg(T),
        };
    };
}

const ParamForParsing = struct {
    arg_flags: anytype,
    no_arg: anytype,
    anon: anytype,
    handlers: anytype,

    const Handler = union(enum) {
        flag_arg: FlagArgPacked,
        no_arg,
        anon_arg: AnonArgPacked,
    };

    fn fromParam(comptime param: Param) @This() {
        comptime var arg_flags = .{};
        comptime var no_arg_flags = .{};
        comptime var anons = .{};
        comptime var handlers = .{};
        inline for (param.ones) |one, i| {
            switch (one) {
                One.arg_flag => |flag| {
                    arg_flags = arg_flags ++ .{.{ flag.flag, i }};
                    handlers = handlers ++ .{Handler{ .flag_arg = flag.arg.pack() }};
                },
                One.no_arg_flag => |no_arg| {
                    no_arg_flags = no_arg_flags ++ .{.{ no_arg.flag, i }};
                    handlers = handlers ++ .{Handler{.no_arg}};
                },
                One.arg_anon => |anon| {
                    anons = anons ++ .{i};
                    handlers = handlers ++ .{Handler{ .anon_arg = anon.arg.pack() }};
                },
            }
        }
        const ComptimeStringMap = std.comptime_string_map.ComptimeStringMap;
        return ParamForParsing{ .arg_flags = ComptimeStringMap(usize, arg_flags), .no_arg_flags = ComptimeStringMap(usize, no_arg_flags), .anons = anons, .handlers = handlers };
    }
};

const Param = struct {
    ones: anytype,
};

test "can construct ParamForParsing" {
    const param = Param{ .ones = .{} };
}
