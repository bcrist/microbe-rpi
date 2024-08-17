pub const Channel = enum (u3) {
    ch0 = 0,
    ch1 = 1,
    ch2 = 2,
    ch3 = 3,
    ch4 = 4,
    ch5 = 5,
    ch6 = 6,
    ch7 = 7,

    pub fn from_pad(pad: Pad_ID) Channel {
        return switch (pad) {
            .GPIO0, .GPIO1, .GPIO16, .GPIO17 => .ch0,
            .GPIO2, .GPIO3, .GPIO18, .GPIO19 => .ch1,
            .GPIO4, .GPIO5, .GPIO20, .GPIO21 => .ch2,
            .GPIO6, .GPIO7, .GPIO22, .GPIO23 => .ch3,
            .GPIO8, .GPIO9, .GPIO24, .GPIO25 => .ch4,
            .GPIO10, .GPIO11, .GPIO26, .GPIO27 => .ch5,
            .GPIO12, .GPIO13, .GPIO28, .GPIO29 => .ch6,
            .GPIO14, .GPIO15 => .ch7,
            else => @compileError("Invalid pad for PWM"),
        };
    }
};

pub const AB = enum (u1) {
    a = 0,
    b = 1,

    pub fn from_pad(pad: Pad_ID) AB {
        return switch (pad) {
            .GPIO0,  .GPIO2,  .GPIO4,  .GPIO6,
            .GPIO8,  .GPIO10, .GPIO12, .GPIO14,
            .GPIO16, .GPIO18, .GPIO20, .GPIO22,
            .GPIO24, .GPIO26, .GPIO28 => .a,

            .GPIO1,  .GPIO3,  .GPIO5,  .GPIO7,
            .GPIO9,  .GPIO11, .GPIO13, .GPIO15,
            .GPIO17, .GPIO19, .GPIO21, .GPIO23,
            .GPIO25, .GPIO27, .GPIO29 => .b,

            else => @compileError("Invalid pad for PWM"),
        };

    }
};

pub const Config = struct {
    name: [*:0]const u8 = "PWM",
    clocks: clocks.Parsed_Config = clocks.get_config(),
    channel: ?Channel = null,
    output: ?Pad_ID,
    output_config: gpio.Config = .{
        .speed = .slow,
        .strength = .@"4mA",
        .output_disabled = false,
    },
    polarity: enum {
        high_below_threshold,
        low_below_threshold,
    } = .high_below_threshold,
    clock: union (enum) {
        frequency_hz: comptime_int,
        divisor_16ths: u12,
    },
    max_count: comptime_int,
};

pub const Channel_Config = struct {
    divisor_16ths: u12,
    max_count: u16,
};
pub fn Channel_Configs() type {
    comptime var configs: std.EnumMap(Channel, Channel_Config) = .{};

    return struct {
        pub fn update(comptime channel: Channel, comptime config: Channel_Config) void {
            if (configs.get(channel)) |existing| {
                if (existing.max_count != config.max_count) {
                    @compileError(std.fmt.comptimePrint("Can't set PWM channel {} to max count of {}; must be {}", .{
                        @intFromEnum(channel),
                        config.max_count,
                        existing.max_count,
                    }));
                }
                if (existing.divisor_16ths != config.divisor_16ths) {
                    @compileError(std.fmt.comptimePrint("Can't set PWM channel {} to divisor_16ths {}; must be {}", .{
                        @intFromEnum(channel),
                        config.divisor_16ths,
                        existing.divisor_16ths,
                    }));
                }
            } else {
                configs.put(channel, config);
            }
        }
    };
}

pub fn PWM(comptime cfg: Config) type {
    const computed_channel = cfg.channel orelse Channel.from_pad(cfg.output orelse @compileError("Channel or output must be specified"));
    const ab: AB = if (cfg.output) |pad| AB.from_pad(pad) else .a;

    if (cfg.output) |pad| {
        const expected_channel = Channel.from_pad(pad);
        if (expected_channel != computed_channel) {
            @compileError(std.fmt.comptimePrint("Expected channel {} for output pad {s}", .{
                @intFromEnum(expected_channel),
                @tagName(pad),
            }));
        }
        validation.pads.reserve(pad, cfg.name);
    }

    if (cfg.max_count == 0) {
        @compileError("Max Count must be positive!");
    }

    const div_16ths = switch (cfg.clock) {
        .frequency_hz => |hz| d: {
            const sys_clk = cfg.clocks.sys.frequency_hz;
            const div_16ths = std.math.clamp(util.div_round(sys_clk * 16, cfg.max_count * hz), 0x10, 0xFFF);
            const actual_frequency_hz = util.div_round(sys_clk * 16, cfg.max_count * div_16ths);
            if (actual_frequency_hz != hz) {
                @compileError(std.fmt.comptimePrint("Cannot achieve frequency {}; closest possible is {}", .{
                    util.fmt_frequency(hz),
                    util.fmt_frequency(actual_frequency_hz),
                }));
            }
            break :d div_16ths;
        },
        .divisor_16ths => |div| div,
    };

    Channel_Configs().update(computed_channel, .{
        .max_count = cfg.max_count,
        .divisor_16ths = div_16ths,
    });

    const periph = &chip.peripherals.PWM.channel[@intFromEnum(computed_channel)];

    return struct {
        pub const config = cfg;
        pub const channel = computed_channel;

        pub fn init() void {
            resets.ensure_not_in_reset(.{
                .pwm = true,
                .pads_bank0 = config.output != null,
            });

            const invert = switch (config.polarity) {
                .high_below_threshold => false,
                .low_below_threshold => true,
            };

            switch (ab) {
                .a => periph.control.modify(.{
                    .enabled = false,
                    .phase_correct = false,
                    .invert_a = invert,
                    .clock_mode = .free_running,
                }),
                .b => periph.control.modify(.{
                    .enabled = false,
                    .phase_correct = false,
                    .invert_b = invert,
                    .clock_mode = .free_running,
                }),
            }

            if (config.output) |pad| {
                gpio.set_function(pad, .pwm);
                gpio.configure(&.{ pad }, config.output_config);
            }

            periph.counter.write(.{
                .count = 0,
            });

            periph.top.write(.{
                .count = config.max_count - 1,
            });

            periph.divisor.write(.{
                .div_16ths = div_16ths,
            });
        }

        pub fn start() void {
            periph.control.set_bits(.enabled);
        }

        pub fn stop() void {
            periph.control.clear_bits(.enabled);
        }

        pub fn set_threshold(count: u16) void {
            switch (ab) {
                .a => periph.compare.rmw(.{ .a = count }),
                .b => periph.compare.rmw(.{ .b = count }),
            }
        }
    };
}

const validation = chip.validation;
const clocks = chip.clocks;
const resets = chip.resets;
const gpio = chip.gpio;
const Pad_ID = chip.Pad_ID;
const reg_types = chip.reg_types;
const chip = @import("chip");
const util = @import("microbe").util;
const std = @import("std");
