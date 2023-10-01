const std = @import("std");
const chip = @import("chip");
const microbe = @import("microbe");
const root = @import("root");
const util = @import("chip_util");
const timing = @import("timing.zig");

pub const RoscParams = struct {
    range: union(enum) {
        low: [8]chip.reg_types.clk.RoscStageDriveStrength,
        medium: [6]chip.reg_types.clk.RoscStageDriveStrength,
        high: [4]chip.reg_types.clk.RoscStageDriveStrength,
    },
    divisor: comptime_int, // 1 - 32

    pub const default: RoscParams = .{
        .range = .{ .low = .{
            .@"1x", .@"1x", .@"1x", .@"1x",
            .@"1x", .@"1x", .@"1x", .@"1x",
        }},
        .divisor = 16,
    };
};

pub const RoscConfig = union(enum) {
    // This will not be very accurate, depends heavily on process/voltage/temperature
    frequency_hz: comptime_int,
    manual: RoscParams,
};

pub const Config = struct {
    rosc: ?RoscConfig = null,

    xosc: ?struct {
        /// Depends on crystal; typically 12 MHz for compatibility with USB boot ROM
        frequency_hz: comptime_int = 12_000_000,
        startup_delay_cycles: comptime_int = 50_000,
    } = null,

    sys_pll: ?PllConfig = null,
    usb_pll: ?PllConfig = null,

    gpin: [2]?struct {
        pad: chip.PadID,
        invert: bool,
        hysteresis: bool,
        maintenance: chip.reg_types.io.PinMaintenance,
        frequency_hz: comptime_int,
    } = .{ null, null },

    ref: struct {
        source: ?enum {
            rosc,
            xosc,
            usb_pll,
            gpin0,
            gpin1,
        },
        frequency_hz: ?comptime_int,
    } = .{ .source = null, .frequency_hz = null },

    sys: struct {
        source: ?enum {
            ref,
            sys_pll,
            usb_pll,
            rosc,
            xosc,
            gpin0,
            gpin1,
        },
        frequency_hz: ?comptime_int,
    } = .{ .source = null, .frequency_hz = null },

    microtick: struct {
        source: enum {
            ref,
        } = .ref,
        period_ns: comptime_int,
    } = .{ .period_ns = 1_000 },

    tick: ?struct {
        source: enum {
            sys,
            microtick,
        } = .microtick,
        period_ns: comptime_int,
    } = .{ .period_ns = 10_000_000 },

    gpout: [4]?struct {
        pad: chip.PadID,
        source: enum {
            sys_pll,
            usb_pll,
            rosc,
            xosc,
            gpin0,
            gpin1,
            ref,
            sys,
            usb,
            adc,
            rtc,
        },
        frequency_hz: ?comptime_int = null,
        invert: bool = false,
        slew: chip.reg_types.io.SlewRate,
        strength: chip.reg_types.io.DriveStrength,
    } = .{ null, null, null, null },

    /// a.k.a. clk_peri
    uart_spi: ?struct {
        source: enum {
            sys,
            sys_pll,
            usb_pll,
            rosc,
            xosc,
            gpin0,
            gpin1,
        } = .sys,
    } = null,

    usb: ?struct {
        source: ?UsbAdcRtcSource = null,
        frequency_hz: comptime_int = 48_000_000,
    } = null,

    adc: ?struct {
        source: ?UsbAdcRtcSource = null,
        frequency_hz: comptime_int = 48_000_000,
    } = null,

    rtc: ?struct {
        source: UsbAdcRtcSource,
        frequency_hz: comptime_int,
    } = null,

    // TODO sys clock resuscitation config
    // TODO watchdog timeout config
};

pub const UsbAdcRtcSource = enum {
    sys_pll,
    usb_pll,
    rosc,
    xosc,
    gpin0,
    gpin1,
};

pub const GenericSource = enum {
    sys_pll,
    usb_pll,
    rosc,
    xosc,
    gpin0,
    gpin1,
    ref,
    sys,
    usb,
    adc,
    rtc,
    microtick,

    pub fn getFrequencyFromConfig(comptime self: GenericSource, comptime parsed: ParsedConfig) comptime_int {
        return switch (self) {
            .sys_pll => parsed.sys_pll.frequency_hz,
            .usb_pll => parsed.usb_pll.frequency_hz,
            .rosc => parsed.rosc.frequency_hz,
            .xosc => parsed.xosc.frequency_hz,
            .gpin0 => parsed.gpin[0].frequency_hz,
            .gpin1 => parsed.gpin[1].frequency_hz,
            .ref => parsed.ref.frequency_hz,
            .sys => parsed.sys.frequency_hz,
            .usb => parsed.usb.frequency_hz,
            .adc => parsed.adc.frequency_hz,
            .rtc => parsed.rtc.frequency_hz,
            .microtick => parsed.microtick.frequency_hz,
        };
    }
};

pub const GenericClockGeneratorConfig = struct {
    source: GenericSource,
    divisor_256ths: comptime_int,
    frequency_hz: comptime_int,
    period_ns: comptime_int,

    pub fn init(comptime source: GenericSource, comptime target_frequency_hz: comptime_int, comptime fractional_divisor: bool, comptime parsed: ParsedConfig) GenericClockGeneratorConfig {
        const source_frequency_hz = source.getFrequencyFromConfig(parsed);
        if (source_frequency_hz == 0) {
            @compileError("Source clock is disabled");
        }

        var divisor_256ths = util.divRound(source_frequency_hz * 256, target_frequency_hz);
        if (fractional_divisor) {
            if (divisor_256ths < 0x180) {
                divisor_256ths = 0x100;
            } else if (divisor_256ths < 0x200) {
                divisor_256ths = 0x200;
            } else if (divisor_256ths > 0xFFFF_FFFF) {
                divisor_256ths = 0xFFFF_FFFF;
            }
        } else if (divisor_256ths < 0x180) {
            divisor_256ths = 0x100;
        } else if (divisor_256ths < 0x280) {
            divisor_256ths = 0x200;
        } else {
            divisor_256ths = 0x300;
        }
        const frequency_hz = util.divRound(source_frequency_hz * 256, divisor_256ths);
        if (frequency_hz != target_frequency_hz) {
            @compileError(std.fmt.comptimePrint("Cannot achieve clock generator target frequency {}; closest possible is {}", .{
                util.fmtFrequency(target_frequency_hz),
                util.fmtFrequency(frequency_hz),
            }));
        }

        return .{
            .source = source,
            .divisor_256ths = divisor_256ths,
            .frequency_hz = frequency_hz,
            .period_ns = util.divRound(1_000_000_000, frequency_hz),
        };
    }

    pub fn integerDivisor(comptime self: GenericClockGeneratorConfig) chip.reg_types.clk.Div123 {
        return switch (self.divisor_256ths) {
            0x100 => .none,
            0x200 => .div2,
            0x300 => .div3,
            else => unreachable,
        };
    }

    pub fn isFractionalDivisor(self: GenericClockGeneratorConfig) bool {
        return (self.divisor_256ths & 0xFF) != 0;
    }

    pub fn shouldUseDutyCycleCorrection(self: GenericClockGeneratorConfig) bool {
        return self.divisor_256ths >= 0x300 and !self.isFractionalDivisor();
    }

    pub const default: GenericClockGeneratorConfig = .{
        .source = .rosc,
        .divisor_256ths = 256,
        .frequency_hz = 0,
        .period_ns = 0,
    };
};

pub const ParsedConfig = struct {
    xosc: struct {
        /// Depends on crystal; typically 12 MHz for compatibility with USB boot ROM
        frequency_hz: comptime_int,
        period_ns: comptime_int,
        startup_delay_cycles: comptime_int = 50_000,
    },
    rosc: struct {
        frequency_hz: comptime_int,
        period_ns: comptime_int,
        params: RoscParams,
    },
    sys_pll: ParsedPllConfig,
    usb_pll: ParsedPllConfig,
    gpin: [2]struct {
        pad: chip.PadID,
        invert: bool,
        hysteresis: bool,
        maintenance: chip.reg_types.io.PinMaintenance,
        frequency_hz: comptime_int,
        period_ns: comptime_int,
    },
    ref: GenericClockGeneratorConfig,
    sys: GenericClockGeneratorConfig,
    microtick: struct {
        source: GenericSource,
        period_ns: comptime_int,
        frequency_hz: comptime_int,
        watchdog_cycles: comptime_int,
    },
    tick: struct {
        source: GenericSource,
        period_ns: comptime_int,
        frequency_hz: comptime_int,
        reload_value: comptime_int,
    },
    uart_spi: GenericClockGeneratorConfig,
    usb: GenericClockGeneratorConfig,
    adc: GenericClockGeneratorConfig,
    rtc: GenericClockGeneratorConfig,
    gpout: [4]struct {
        pad: chip.PadID,
        invert: bool,
        slew: chip.reg_types.io.SlewRate,
        strength: chip.reg_types.io.DriveStrength,
        generator: GenericClockGeneratorConfig,
    },
};

pub fn getConfig() ParsedConfig {
    return comptime if (@hasDecl(root, "clocks")) parseConfig(root.clocks) else reset_config;
}

pub const reset_config = parseConfig(.{
    .rosc = .{ .manual = RoscParams.default },
});

pub fn parseConfig(comptime config: Config) ParsedConfig {
    return comptime done: {
        var parsed = ParsedConfig{
            .rosc = .{
                .frequency_hz = 0,
                .period_ns = 0,
                .params = RoscParams.default,
            },
            .xosc = .{
                .frequency_hz = 0,
                .period_ns = 0,
            },
            .sys_pll = ParsedPllConfig.disabled,
            .usb_pll = ParsedPllConfig.disabled,
            .gpin = .{
                .{
                    .pad = .GPIO20,
                    .frequency_hz = 0,
                    .period_ns = 0,
                    .invert = false,
                    .hysteresis = true,
                    .maintenance = .float,
                },
                .{
                    .pad = .GPIO22,
                    .frequency_hz = 0,
                    .period_ns = 0,
                    .invert = false,
                    .hysteresis = true,
                    .maintenance = .float,
                },
            },
            .ref = GenericClockGeneratorConfig.default,
            .sys = GenericClockGeneratorConfig.default,
            .uart_spi = GenericClockGeneratorConfig.default,
            .usb = GenericClockGeneratorConfig.default,
            .adc = GenericClockGeneratorConfig.default,
            .rtc = GenericClockGeneratorConfig.default,
            .microtick = .{
                .source = .ref,
                .period_ns = 0,
                .frequency_hz = 0,
                .watchdog_cycles = 0,
            },
            .tick = .{
                .source = .ref,
                .period_ns = 0,
                .frequency_hz = 0,
                .reload_value = 0,
            },
            .gpout = .{
                .{
                    .pad = .GPIO21,
                    .invert = false,
                    .slew = .slow,
                    .strength = .@"2mA",
                    .generator = .{
                        .source = .ref,
                        .divisor_256ths = 256,
                        .frequency_hz = 0,
                        .period_ns = 0,
                    },
                },
                .{
                    .pad = .GPIO23,
                    .invert = false,
                    .slew = .slow,
                    .strength = .@"2mA",
                    .generator = .{
                        .source = .ref,
                        .divisor_256ths = 256,
                        .frequency_hz = 0,
                        .period_ns = 0,
                    },
                },
                .{
                    .pad = .GPIO24,
                    .invert = false,
                    .slew = .slow,
                    .strength = .@"2mA",
                    .generator = .{
                        .source = .ref,
                        .divisor_256ths = 256,
                        .frequency_hz = 0,
                        .period_ns = 0,
                    },
                },
                .{
                    .pad = .GPIO25,
                    .invert = false,
                    .slew = .slow,
                    .strength = .@"2mA",
                    .generator = .{
                        .source = .ref,
                        .divisor_256ths = 256,
                        .frequency_hz = 0,
                        .period_ns = 0,
                    },
                },
            },
        };

        if (config.rosc) |rosc| {
            switch (rosc) {
                .manual => |params| {
                    parsed.rosc.frequency_hz = 6_000_000; // TODO
                    parsed.rosc.params = params;
                },
                .frequency_hz => |freq| {
                    parsed.rosc.frequency_hz = freq;
                    // TODO params
                },
            }
            parsed.rosc.period_ns = util.divRound(1_000_000_000, parsed.rosc.frequency_hz);
        }

        if (config.xosc) |xosc| {
            parsed.xosc.frequency_hz = xosc.frequency_hz;
            parsed.xosc.period_ns = util.divRound(1_000_000_000, xosc.frequency_hz);
            parsed.xosc.startup_delay_cycles = (xosc.startup_delay_cycles / 256) * 256;
            if (xosc.frequency_hz < 1_000_000) @compileError("XOSC frequency should be at least 1 MHz");
            if (xosc.frequency_hz > 50_000_000) @compileError("XOSC frequency should be <= 50 MHz (15 MHz if using a crystal)");
        }

        if (config.sys_pll) |pll| {
            parsed.sys_pll = parsePllConfig(pll, parsed.xosc.frequency_hz);
        }

        if (config.usb_pll) |pll| {
            parsed.usb_pll = parsePllConfig(pll, parsed.xosc.frequency_hz);
        }

        inline for (0..2) |n| {
            if (config.gpin[n]) |gpin| {
                const io: chip.PadID = switch (n) {
                    0 => .GPIO20,
                    1 => .GPIO22,
                };
                if (gpin.pad != io) {
                    @compileError(std.fmt.comptimePrint("Expected pad {s} for GP clock input {}", .{ @tagName(io), n }));
                }

                parsed.gpin[n] = .{
                    .pad = gpin.pad,
                    .invert = gpin.invert,
                    .hysteresis = gpin.hysteresis,
                    .maintenance = gpin.maintenance,
                    .frequency_hz = gpin.frequency_hz,
                    .period_ns = util.divRound(1_000_000_000, gpin.frequency_hz),
                };
                checkFrequency("GPIN", parsed.gpin[n].frequency_hz, 1, 50_000_000);
            }
        }

        const ref_source = src: {
            if (config.ref.source) |source| {
                break :src std.enums.nameCast(GenericSource, @tagName(source));
            }
            break :src if (parsed.xosc.frequency_hz > 0) .xosc else .rosc;
        };
        const ref_source_freq = ref_source.getFrequencyFromConfig(parsed);
        if (ref_source_freq == 0) @compileError(std.fmt.comptimePrint("Ref clock source (.{s}) is not configured!", .{ @tagName(ref_source) }));
        parsed.ref = GenericClockGeneratorConfig.init(ref_source, config.ref.frequency_hz orelse ref_source_freq, false, parsed);
        checkFrequency("ref", parsed.ref.frequency_hz, 1, 133_000_000);

        const sys_source = src: {
            if (config.sys_source) |source| {
                break :src std.enums.nameCast(GenericSource, @tagName(source));
            }
            if (parsed.sys_pll.frequency_hz > 0) break :src .sys_pll;
            break :src if (parsed.xosc.frequency_hz > 0) .xosc else .rosc;
        };
        const sys_source_freq = sys_source.getFrequencyFromConfig(parsed);
        if (sys_source_freq == 0) @compileError(std.fmt.comptimePrint("Sys clock source (.{s}) is not configured!", .{ @tagName(sys_source) }));
        parsed.sys = GenericClockGeneratorConfig.init(sys_source, config.sys.frequency_hz orelse sys_source.getFrequencyFromConfig(parsed), true, parsed);
        checkFrequency("sys", parsed.sys.frequency_hz, 1, 133_000_000);

        {
            parsed.microtick.source = std.enums.nameCast(GenericSource, @tagName(config.microtick.source));
            const source_frequency_hz = parsed.microtick.source.getFrequencyFromConfig(parsed);

            parsed.microtick.period_ns = config.microtick.period_ns;
            const divisor = util.divRound(source_frequency_hz * parsed.microtick.period_ns, 1_000_000_000);
            if (divisor == 0) {
                @compileError(std.fmt.comptimePrint("Ref clock ({}) too slow for microtick period ({} ns)", .{
                    util.fmtFrequency(source_frequency_hz),
                    parsed.microtick.period_ns,
                }));
            } else if (divisor >= 512) {
                @compileError(std.fmt.comptimePrint("Ref clock ({}) too fast for microtick priod ({} ns); div={}!", .{
                    util.fmtFrequency(source_frequency_hz),
                    parsed.microtick.period_ns,
                    divisor,
                }));
            }

            parsed.microtick.watchdog_cycles = divisor;
            parsed.microtick.frequency_hz = util.divRound(source_frequency_hz, divisor);
            
            const actual_period = util.divRound(divisor * 1_000_000_000, parsed.ref.frequency_hz);
                if (actual_period != parsed.microtick.period_ns) {
                    @compileError(std.fmt.comptimePrint("Invalid microtick period; closest match is {} ns ({} cycles, {} microtick, {} source clock)", .{
                        actual_period,
                        divisor,
                        util.fmtFrequency(parsed.microtick.frequency_hz),
                        util.fmtFrequency(source_frequency_hz),
                    }));
                }
            checkFrequency("microtick", parsed.microtick.frequency_hz, 1, 133_000_000);
        }

        if (config.tick) |tick| {
            parsed.tick.source = std.enums.nameCast(GenericSource, @tagName(tick.source));
            const source_frequency_hz = parsed.tick.source.getFrequencyFromConfig(parsed);

            parsed.tick.period_ns = tick.period_ns;
            var cycles_per_interrupt = util.divRound(source_frequency_hz * tick.period_ns, 1_000_000_000);

            // systick interrupt only fires if RELOAD is > 0, and RELOAD is cycles_per_interrupt - 1,
            cycles_per_interrupt = @max(2, cycles_per_interrupt);

            const actual_freq = util.divRound(source_frequency_hz, cycles_per_interrupt);
            const actual_period = util.divRound(cycles_per_interrupt * 1_000_000_000, source_frequency_hz);
            if (actual_period != tick.period_ns) {
                @compileError(std.fmt.comptimePrint("Invalid tick period; closest match is {} ns ({} cycles per interrupt, {} tick, {} source clock)", .{
                    actual_period,
                    cycles_per_interrupt,
                    util.fmtFrequency(actual_freq),
                    util.fmtFrequency(source_frequency_hz),
                }));
            }
            parsed.tick.frequency_hz = actual_freq;
            parsed.tick.reload_value = cycles_per_interrupt - 1;
            checkFrequency("tick", parsed.tick.frequency_hz, 1, 1_000_000);
        }

        if (config.uart_spi) |uart_spi| {
            const source = std.enums.nameCast(GenericSource, @tagName(uart_spi.source));
            parsed.uart_spi = GenericClockGeneratorConfig.init(source, source.getFrequencyFromConfig(parsed), false, parsed);
            checkFrequency("UART/SPI", parsed.uart_spi.frequency_hz, 1, 133_000_000);
        }

        if (config.usb) |usb| {
            const source = src: {
                if (usb.source) |source| {
                    break :src std.enums.nameCast(GenericSource, @tagName(source));
                }
                break :src if (parsed.usb_pll.frequency_hz > 0) .usb_pll else .sys_pll;
            };
            parsed.usb = GenericClockGeneratorConfig.init(source, usb.frequency_hz, false, parsed);
            checkFrequency("USB", parsed.usb.frequency_hz, 47_999_000, 48_001_000);
        }

        if (config.adc) |adc| {
            const source = src: {
                if (adc.source) |source| {
                    break :src std.enums.nameCast(GenericSource, @tagName(source));
                }
                break :src if (parsed.usb_pll.frequency_hz > 0) .usb_pll else .sys_pll;
            };
            parsed.usb = GenericClockGeneratorConfig.init(source, adc.frequency_hz, false, parsed);
            checkFrequency("ADC", parsed.adc.frequency_hz, 47_990_000, 48_010_000);
        }

        if (config.rtc) |rtc| {
            const source = std.enums.nameCast(GenericSource, @tagName(rtc.source));
            parsed.usb = GenericClockGeneratorConfig.init(source, rtc.frequency_hz, true, parsed);
            checkFrequency("RTC", parsed.rtc.frequency_hz, 1, 65536);
        }

        for (0.., config.gpout, &parsed.gpout) |n, maybe_gpout, *parsed_gpout| {
            if (maybe_gpout) |gpout| {
                const io: chip.PadID = switch (n) {
                    0 => .GPIO21,
                    1 => .GPIO23,
                    2 => .GPIO24,
                    3 => .GPIO25,
                    else => unreachable,
                };
                if (gpout.pad != io) {
                    @compileError(std.fmt.comptimePrint("Expected pad {s} for GP clock output {}", .{ @tagName(io), n }));
                }

                const source = std.enums.nameCast(GenericSource, @tagName(gpout.source));
                parsed_gpout.pad = gpout.pad;
                parsed_gpout.invert = gpout.invert;
                parsed_gpout.slew = gpout.slew;
                parsed_gpout.strength = gpout.strength;
                parsed_gpout.generator = GenericClockGeneratorConfig.init(source, source.getFrequencyFromConfig(parsed), true, parsed);

                checkFrequency("GPOUT", parsed_gpout.frequency_hz, 1, 50_000_000);
            }
        }

        break :done parsed;
    };
}

pub const PllConfig = struct {
    vco: union(enum) {
        auto: void,
        /// VCO frequency must be between 750-1600 MHz,
        /// and an integer multiple (6x - 49x) of the output frequency
        frequency_hz: comptime_int,
        manual: struct {
            /// xosc / divisor must be >= 5 MHz
            divisor: comptime_int, // 1 - 63
            multiplier: comptime_int, // 16 - 320
        },
    } = .{ .auto = {} },
    frequency_hz: comptime_int = 0,
};

pub const ParsedPllConfig = struct {
    vco: struct {
        divisor: comptime_int, // 1 - 63
        multiplier: comptime_int, // 16 - 320
        frequency_hz: comptime_int,
        period_ns: comptime_int,
    },
    output_divisor0: comptime_int, // 1 - 7
    output_divisor1: comptime_int, // 1 - 7
    frequency_hz: comptime_int,
    period_ns: comptime_int,

    pub const disabled = ParsedPllConfig {
        .vco = .{
            .divisor = 1,
            .multiplier = 16,
            .frequency_hz = 0,
            .period_ns = 0,
        },
        .output_divisor0 = 7,
        .output_divisor1 = 7,
        .frequency_hz = 0,
        .period_ns = 0,
    };
};

pub fn parsePllConfig(comptime config: PllConfig, comptime xosc_frequency_hz: comptime_int) ParsedPllConfig {
    if (config.frequency_hz == 0) @compileError("PLL output frequency must be > 0; use .sys_pll = null or .usb_pll = null to disable");

    return switch (config.vco) {
        .auto => pllParamsAuto(.{
            .xosc_frequency_hz = xosc_frequency_hz,
            .out_frequency_hz = config.frequency_hz,
        }),
        .frequency_hz => |vco_freq| pllParamsExplicitVco(.{
            .xosc_frequency_hz = xosc_frequency_hz,
            .vco_frequency_hz = vco_freq,
            .out_frequency_hz = config.frequency_hz,
        }),
        .manual => |params| pllParamsManual(.{
            .xosc_frequency_hz = xosc_frequency_hz,
            .divisor = params.divisor,
            .multiplier = params.multiplier,
            .out_frequency_hz = config.frequency_hz,
        }),
    };
}

pub const PllParamsManualOptions = struct {
    xosc_frequency_hz: comptime_int,
    divisor: comptime_int,
    multiplier: comptime_int,
    out_frequency_hz: comptime_int,
};
pub fn pllParamsManual(comptime options: PllParamsManualOptions) ParsedPllConfig {
    @setEvalBranchQuota(1_000_000);
    return comptime done: {
        if (options.xosc_frequency_hz < 5_000_000) @compileError("XOSC frequency must be >= 5 MHz when using PLLs");
        if (options.divisor < 1) @compileError("PLL input divisor must be >= 1");
        if (options.divisor > 63) @compileError("PLL input divisor must be <= 63");

        if (options.multiplier < 16) @compileError("PLL multiplier must be >= 16");
        if (options.multiplier > 320) @compileError("PLL multiplier must be <= 320");

        var config = ParsedPllConfig {
            .vco = .{
                .divisor = options.divisor,
                .multiplier = options.multiplier,
                .frequency_hz = util.divRound(options.xosc_frequency_hz * options.multiplier, options.divisor),
                .period_ns = 0,
            },
            .output_divisor0 = 1,
            .output_divisor1 = 1,
            .frequency_hz = 0,
            .period_ns = 0,
        };

        config.vco.period_ns = util.divRound(1_000_000_000, config.vco.frequency_hz);

        checkFrequency("VCO", config.vco.frequency_hz, 750_000_000, 1_600_000_000);
        findPllOutputDivisors(&config, options.out_frequency_hz);

        break :done config;
    };
}

fn findPllOutputDivisors(comptime config: *ParsedPllConfig, comptime out_frequency_hz: comptime_int) void {
    comptime done: {
        var closest_match_freq = 0;
        var closest_low_match_freq = 0;
        for (1..8) |divisor0| {
            const f0 = util.divRound(config.vco.frequency_hz, divisor0);
            if (f0 < closest_low_match_freq) break;

            for (1 .. divisor0 + 1) |divisor1| {
                const f1 = util.divRound(f0, divisor1);

                if (f1 == out_frequency_hz) {
                    config.output_divisor0 = divisor0;
                    config.output_divisor1 = divisor1;
                    config.frequency_hz = f1;
                    config.period_ns = util.divRound(1_000_000_000, f1);
                    break :done;
                } else if (f1 < closest_low_match_freq) {
                    break;
                } else if (f1 < out_frequency_hz) {
                    closest_low_match_freq = f1;
                }

                const delta = std.math.absInt(f1 - out_frequency_hz);
                const closest_delta = std.math.absInt(closest_match_freq - out_frequency_hz);

                if (delta < closest_delta) {
                    closest_match_freq = f1;
                }
            }
        }

        const error_ppm = std.math.absInt(closest_match_freq - out_frequency_hz) * 1000_000 / out_frequency_hz;

        @compileError(std.fmt.comptimePrint("Can't generate PLL output frequency: {}.  Closest match is {} ({} ppm error)", .{
            util.fmtFrequency(out_frequency_hz),
            util.fmtFrequency(closest_match_freq),
            error_ppm,
        }));
    }
}

pub const PllParamsExplicitVcoOptions = struct {
    xosc_frequency_hz: comptime_int,
    vco_frequency_hz: comptime_int,
    out_frequency_hz: comptime_int,
};
pub fn pllParamsExplicitVco(comptime options: PllParamsExplicitVcoOptions) ParsedPllConfig {
    @setEvalBranchQuota(1_000_000);
    return comptime done: {
        var closest_match_freq = 0;
        for (1..64) |divisor| {
            const input = util.divRound(options.xosc_frequency_hz, options.divisor);
            if (input < 5_000_000) break;

            for (16..321) |multiplier| {
                const vco = input * multiplier;

                if (vco > 1_600_000_000) break;
                if (vco < 750_000_000) continue;

                if (vco == options.vco_frequency_hz) {
                    break :done pllParamsManual(options.xosc_frequency_hz, divisor, multiplier, options.out_frequency_hz);
                }

                const delta = std.math.absInt(vco - options.vco_frequency_hz);
                const closest_delta = std.math.absInt(closest_match_freq - options.vco_frequency_hz);

                if (delta < closest_delta) {
                    closest_match_freq = vco;
                }
            }
        }

        const error_ppm = std.math.absInt(closest_match_freq - options.vco_frequency_hz) * 1000_000 / options.vco_frequency_hz;

        @compileError(std.fmt.comptimePrint("Can't generate PLL VCO frequency: {}.  Closest match is {} ({} ppm error)", .{
            util.fmtFrequency(options.vco_frequency_hz),
            util.fmtFrequency(closest_match_freq),
            error_ppm,
        }));
    };
}

pub const PllParamsAutoOptions = struct {
    xosc_frequency_hz: comptime_int,
    min_vco_frequency_hz: comptime_int = 750_000_000,
    max_vco_frequency_hz: comptime_int = 1_600_000_000,
    out_frequency_hz: comptime_int,
};
pub fn pllParamsAuto(comptime options: PllParamsAutoOptions) ParsedPllConfig {
    @setEvalBranchQuota(1_000_000);
    return comptime done: {
        if (options.xosc_frequency_hz < 5_000_000) @compileError("XOSC frequency must be >= 5 MHz when using PLLs");
        if (options.min_vco_frequency_hz < 750_000_000) @compileError("Minimum VCO frequency is 750 MHz");
        if (options.max_vco_frequency_hz > 1_600_000_000) @compileError("Maximum VCO frequency is 1600 MHz");

        var closest_match: ?ParsedPllConfig = null;
        var closest_low_match_freq = 0;
        for (1..64) |divisor| {
            const input = util.divRound(options.xosc_frequency_hz, divisor);
            if (input < 5_000_000) break;

            for (16..321) |multiplier| {
                const vco = input * multiplier;

                if (vco > options.max_vco_frequency_hz) break;
                if (vco < options.min_vco_frequency_hz) continue;

                for (1..8) |divisor0| {
                    const f0 = util.divRound(vco, divisor0);
                    if (f0 < closest_low_match_freq) break;

                    for (1 .. divisor0 + 1) |divisor1| {
                        const f1 = util.divRound(f0, divisor1);

                        if (f1 == options.out_frequency_hz) {
                            break :done .{
                                .vco = .{
                                    .divisor = divisor,
                                    .multiplier = multiplier,
                                    .frequency_hz = vco,
                                    .period_ns = util.divRound(1_000_000_000, vco),
                                },
                                .output_divisor0 = divisor0,
                                .output_divisor1 = divisor1,
                                .frequency_hz = f1,
                                .period_ns = util.divRound(1_000_000_000, f1),
                            };
                        } else if (f1 < closest_low_match_freq) {
                            break;
                        } else if (f1 < options.out_frequency_hz) {
                            closest_low_match_freq = f1;
                        }

                        if (closest_match) |closest| {
                            const delta = @abs(f1 - options.out_frequency_hz);
                            const closest_delta = @abs(closest.frequency_hz - options.out_frequency_hz);
                            if (delta > closest_delta) {
                                continue;
                            }
                        }

                        closest_match = .{
                            .vco = .{
                                .divisor = divisor,
                                .multiplier = multiplier,
                                .frequency_hz = vco,
                                .period_ns = util.divRound(1_000_000_000, vco),
                            },
                            .output_divisor0 = divisor0,
                            .output_divisor1 = divisor1,
                            .frequency_hz = f1,
                            .period_ns = util.divRound(1_000_000_000, f1),
                        };
                    }
                }
            }
        }

        if (closest_match) |closest| {
            const error_ppm = std.math.absInt(closest.frequency_hz - options.out_frequency_hz) * 1000_000 / options.out_frequency_hz;

            @compileError(std.fmt.comptimePrint(
                \\Can't generate PLL frequency: {}.  Closest match is:
                \\     XOSC frequency: {}
                \\    Input frequency: {} (/{})
                \\      VCO frequency: {} (*{})
                \\    Output divisors: /{} /{}
                \\   Output frequency: {} ({} ppm error)
            , .{
                util.fmtFrequency(options.out_frequency_hz),
                util.fmtFrequency(options.xosc_frequency_hz),
                util.fmtFrequency(util.divRound(options.xosc_frequency_hz, closest.vco.divisor)),
                closest.vco.divisor,
                util.fmtFrequency(closest.vco.frequency_hz),
                closest.vco.multiplier,
                closest.output_divisor0,
                closest.output_divisor1,
                util.fmtFrequency(closest.frequency_hz),
                error_ppm,
            }));
        } else {
            @compileError(std.fmt.comptimePrint("Can't generate PLL frequency: {}", .{ util.fmtFrequency(options.out_frequency_hz) }));
        }
    };
}

fn checkFrequency(comptime name: []const u8, comptime freq: comptime_int, comptime min: comptime_int, comptime max: comptime_int) void {
    comptime {
        if (freq < min) {
            invalidFrequency(name, freq, ">=", min);
        } else if (freq > max) {
            invalidFrequency(name, freq, "<=", max);
        }
    }
}

fn invalidFrequency(comptime name: []const u8, comptime actual: comptime_int, comptime dir: []const u8, comptime limit: comptime_int) void {
    comptime {
        @compileError(std.fmt.comptimePrint("Invalid {s} frequency: {}; must be {s} {}", .{
            name, util.fmtFrequency(actual),
            dir,  util.fmtFrequency(limit),
        }));
    }
}


const PllConfigChange = struct {
    pll: *volatile chip.reg_types.clk.PLL,

    disable_output_divisor: bool = false,
    change_input_divisor: ?u6 = null,
    change_multiplier: ?u12 = null,
    wait_for_stable: bool = false,
    change_output_divisor: ?@TypeOf(chip.PLL_SYS.output).Type = null,
    enable_output_divisor: bool = false,
    shutdown: bool = false,

    pub fn init(comptime self: PllConfigChange) void {
        if (self.disable_output_divisor) {
            self.pll.power.write(.vco_startup);
        }
        if (self.change_input_divisor) |div| {
            self.pll.control_status.write(.{
                .input_divisor = div,
            });
        }
        if (self.change_multiplier) |mult| {
            self.pll.multiplier.write(.{
                .factor = mult,
            });
        }
    }

    pub fn waitForStable(comptime self: PllConfigChange) void {
        if (self.wait_for_stable) {
            while (!self.pll.control_status.read().locked) {}
        }
        if (self.change_output_divisor) |div| {
            self.pll.output.write(div);
        }
        if (self.enable_output_divisor) {
            self.pll.power.write(.run);
        }
    }

    pub fn finish(comptime self: PllConfigChange) void {
        if (self.shutdown) {
            self.pll.power.write(.shutdown);
        }
    }
};

/// This contains all the steps that might potentially be necessary to change
/// from one ParsedConfig to another, or to set up the initial ParsedConfig.
/// It's generated at comptime so that the run() function optimizes to just the necessary operations.
const ConfigChange = struct {
    change_xosc_startup_delay_div256: ?u14 = null,
    start_xosc: bool = false,

    change_rosc_divisor_early: ?RoscDivisor = null,
    change_rosc_drive0: ?@TypeOf(chip.ROSC.drive0).Type = null,
    change_rosc_drive1: ?@TypeOf(chip.ROSC.drive1).Type = null,
    start_rosc: ?@TypeOf(chip.ROSC.control).Type = null,
    change_rosc_divisor_late: ?RoscDivisor = null,

    wait_for_rosc_stable: bool = false,
    wait_for_xosc_stable: bool = false,

    disable_gpout: [4]bool = .{ false, false, false, false },
    disable_peri: bool = false,
    disable_usb: bool = false,
    disable_adc: bool = false,
    disable_rtc: bool = false,
    cycles_to_wait_after_disables: u32 = 0,

    setup_gpin_hysteresis: [2]?bool = .{ null, null },
    setup_gpin_maintenance: [2]?chip.reg_types.io.PinMaintenance = .{ null, null },
    setup_gpin_io: [2]?enum { disabled, normal, inverted } = .{ null, null },

    change_ref_divisor_early: ?chip.reg_types.clk.Div123 = null,
    change_sys_divisor_early: ?u32 = null,
    switch_ref_to_rosc: bool = false,
    switch_ref_to_xosc: bool = false,
    change_ref_divisor_mid: ?chip.reg_types.clk.Div123 = null,

    switch_sys_to_ref: bool = false,
    change_sys_divisor_ref: ?u32 = null,

    sys_pll: PllConfigChange = .{ .pll = chip.PLL_SYS },
    usb_pll: PllConfigChange = .{ .pll = chip.PLL_USB },

    switch_sys_aux: ?std.meta.fieldInfo(@TypeOf(chip.CLOCKS.sys.control).Type, .aux_source).type = null,
    switch_sys_to_aux: bool = false,
    change_sys_divisor_late: ?u32 = null,

    switch_ref_aux: ?std.meta.fieldInfo(@TypeOf(chip.CLOCKS.ref.control).Type, .aux_source).type = null,
    switch_ref_to_aux: bool = false,
    change_ref_divisor_late: ?chip.reg_types.clk.Div123 = null,

    enable_peri: ?std.meta.fieldInfo(@TypeOf(chip.CLOCKS.peri.control).Type, .source).type = null,
    change_usb_divisor: ?chip.reg_types.clk.Div123 = null,
    enable_usb: ?std.meta.fieldInfo(@TypeOf(chip.CLOCKS.usb.control).Type, .source).type = null,
    change_adc_divisor: ?chip.reg_types.clk.Div123 = null,
    enable_adc: ?std.meta.fieldInfo(@TypeOf(chip.CLOCKS.adc.control).Type, .source).type = null,
    change_rtc_divisor: ?u32 = null,
    enable_rtc: ?std.meta.fieldInfo(@TypeOf(chip.CLOCKS.rtc.control).Type, .source).type = null,

    setup_gpout_slew: [4]?chip.reg_types.io.SlewRate = .{ null, null, null, null },
    setup_gpout_strength: [4]?chip.reg_types.io.DriveStrength = .{ null, null, null, null },
    setup_gpout_io: [4]?enum { disabled, normal, inverted } = .{ null, null, null, null },
    change_gpout_divisor: [4]?u32 = .{ null, null, null, null },
    change_gpout_control: [4]?std.meta.fieldInfo(chip.reg_types.clk.GpoutClockGenerator, .control).type = .{ null, null, null, null },
    enable_gpout: [4]?std.meta.fieldInfo(chip.reg_types.clk.GpoutClockGenerator, .control).type = .{ null, null, null, null },

    disable_microtick: bool = false,
    disable_systick: bool = false,
    change_microtick_divisor: ?u9 = null,
    change_systick_source: ?std.meta.fieldInfo(@TypeOf(chip.SYSTICK.control_status).Type, .clock_source).type = null,
    change_systick_reload: ?u24 = null,
    enable_systick: bool = false,
    enable_microtick: bool = false,

    stop_xosc: bool = false,
    stop_rosc: bool = false,

    pub inline fn run(comptime self: ConfigChange) void {
        if (self.change_xosc_startup_delay_div256) |delay| {
            chip.XOSC.startup_delay.write(.{ .cycles_div256 = delay });
        }
        if (self.start_xosc) {
            chip.XOSC.control.modify(.{ .enabled = .enabled });
        }
        if (self.change_rosc_divisor_early) |div| {
            chip.ROSC.output_divisor.write(.{ .divisor = div });
        }
        if (self.change_rosc_drive0) |drive| {
            chip.ROSC.drive0.write(drive);
        }
        if (self.change_rosc_drive1) |drive| {
            chip.ROSC.drive1.write(drive);
        }
        if (self.start_rosc) |control_word| {
            chip.ROSC.control.write(control_word);
        }
        if (self.change_rosc_divisor_late) |div| {
            chip.ROSC.output_divisor.write(.{ .divisor = div });
        }
        inline for (0.., self.disable_gpout) |n, disable| {
            if (disable) {
                chip.CLOCKS.gpout[n].control.modify(.{ .enabled = false });
            }
        }
        if (self.disable_peri) {
            chip.CLOCKS.peri.control.modify(.{ .enabled = false });
        }
        if (self.disable_usb) {
            chip.CLOCKS.usb.control.modify(.{ .enabled = false });
        }
        if (self.disable_adc) {
            chip.CLOCKS.adc.control.modify(.{ .enabled = false });
        }
        if (self.disable_rtc) {
            chip.CLOCKS.rtc.control.modify(.{ .enabled = false });
        }
        if (self.cycles_to_wait_after_disables > 0) {
            timing.blockAtLeastCycles(self.cycles_to_wait_after_disables);
        }
        inline for (0.., self.setup_gpin_hysteresis, self.setup_gpin_maintenance, self.setup_gpin_io) |n, maybe_hyst, maybe_pull, maybe_io_mode| {
            const io = switch (n) {
                0 => 20,
                1 => 22,
                else => unreachable,
            };
            if (maybe_hyst != null or maybe_pull != null) {
                var io_cfg = chip.PADS.gpio[io].read();
                if (maybe_hyst) |hyst| io_cfg.hysteresis = hyst;
                if (maybe_pull) |pull| io_cfg.maintenance = pull;
                io_cfg.input_enabled = true;
                chip.PADS.gpio[io].write(io_cfg);
            }
            if (maybe_io_mode) |mode| {
                switch (mode) {
                    .disabled => chip.IO[io].control.modify(.{
                        .func = .disable,
                        .oe_override = .normal,
                        .input_override = .normal,
                    }),
                    .normal   => chip.IO[io].control.modify(.{
                        .func = .clock,
                        .oe_override = .force_low,
                        .input_override = .normal,
                    }),
                    .inverted => chip.IO[io].control.modify(.{
                        .func = .clock,
                        .oe_override = .force_low,
                        .input_override = .invert,
                    }),
                }
            }
        }
        if (self.wait_for_rosc_stable) {
            while (true) {
                const status = chip.ROSC.status.read();
                if (status.stable or !status.enabled) break;
            }
        }
        if (self.wait_for_xosc_stable) {
            while (true) {
                const status = chip.XOSC.status.read();
                if (status.stable or !status.enabled) break;
            }
        }
        if (self.change_ref_divisor_early) |div| {
            self.CLOCKS.ref.divisor.write(.{ .divisor = div });
        }
        if (self.change_sys_divisor_early) |div| {
            self.CLOCKS.sys.divisor.write(.{ .divisor = div });
        }
        if (self.switch_ref_to_rosc) {
            setGlitchlessRefSource(.rosc);
        }
        if (self.switch_ref_to_xosc) {
            setGlitchlessRefSource(.xosc);
        }
        if (self.change_ref_divisor_mid) |div| {
            chip.CLOCKS.ref.divisor.write(.{ .divisor = div });
        }
        if (self.switch_sys_to_ref) {
            setGlitchlessSysSource(.clk_ref);
        }
        if (self.change_sys_divisor_ref) |div| {
            chip.CLOCKS.sys.divisor.write(.{ .divisor = div });
        }
        self.sys_pll.init();
        self.usb_pll.init();
        self.sys_pll.waitForStable();
        self.usb_pll.waitForStable();
        if (self.switch_sys_aux) |aux_src| {
            chip.CLOCKS.sys.control.modify(.{ .aux_source = aux_src });
        }
        if (self.switch_sys_to_aux) {
            setGlitchlessSysSource(.aux);
        }
        if (self.change_sys_divisor_late) |div| {
            chip.CLOCKS.sys.divisor.write(div);
        }
        if (self.switch_ref_aux) |aux_src| {
            chip.CLOCKS.ref.control.modify(.{ .aux_source = aux_src });
        }
        if (self.switch_ref_to_aux) {
            setGlitchlessRefSource(.aux);
        }
        if (self.change_ref_divisor_late) |div| {
            chip.CLOCKS.ref.divisor.write(.{ .divisor = div });
        }
        if (self.enable_peri) |src| {
            chip.CLOCKS.peri.control.write(.{
                .source = src,
            });
            chip.CLOCKS.peri.control.write(.{
                .source = src,
                .enabled = true,
            });
        }
        if (self.change_usb_divisor) |div| {
            chip.CLOCKS.usb.divisor.write(.{ .divisor = div });
        }
        if (self.enable_usb) |src| {
            chip.CLOCKS.usb.control.write(.{
                .source = src,
            });
            chip.CLOCKS.usb.control.write(.{
                .source = src,
                .enabled = true,
            });
        }
        if (self.change_adc_divisor) |div| {
            chip.CLOCKS.adc.divisor.write(.{ .divisor = div });
        }
        if (self.enable_adc) |src| {
            chip.CLOCKS.adc.control.write(.{
                .source = src,
            });
            chip.CLOCKS.adc.control.write(.{
                .source = src,
                .enabled = true,
            });
        }
        if (self.change_rtc_divisor) |div| {
            chip.CLOCKS.rtc.divisor.write(div);
        }
        if (self.enable_rtc) |src| {
            chip.CLOCKS.rtc.control.write(.{
                .source = src,
            });
            chip.CLOCKS.rtc.control.write(.{
                .source = src,
                .enabled = true,
            });
        }
        inline for (0..,
            self.setup_gpout_slew,
            self.setup_gpout_strength,
            self.setup_gpout_io,
            self.change_gpout_divisor,
            self.change_gpout_control,
            self.enable_gpout
        ) |n, maybe_slew, maybe_strength, maybe_io_mode, maybe_div, maybe_ctrl, maybe_enable| {
            if (maybe_div) |div| {
                chip.CLOCKS.gpout[n].divisor.write(div);
            }
            if (maybe_ctrl) |ctrl| {
                chip.CLOCKS.gpout[n].control.write(ctrl);
            }
            if (maybe_enable) |ctrl| {
                chip.CLOCKS.gpout[n].control.write(ctrl);
            }
            const io = switch (n) {
                0 => 21,
                1 => 23,
                2 => 24,
                3 => 25,
                else => unreachable,
            };

            if (maybe_slew != null or maybe_strength != null) {
                var io_cfg = chip.PADS.gpio[io].read();
                if (maybe_slew) |slew| io_cfg.speed = slew;
                if (maybe_strength) |strength| io_cfg.strength = strength;
                io_cfg.output_disabled = false;
                chip.PADS.gpio[io].write(io_cfg);
            }
            if (maybe_io_mode) |mode| {
                switch (mode) {
                    .disabled => chip.IO[io].control.modify(.{
                        .func = .disable,
                        .output_override = .normal,
                        .oe_override = .normal,
                    }),
                    .normal   => chip.IO[io].control.modify(.{
                        .func = .clock,
                        .output_override = .normal,
                        .oe_override = .force_high,
                    }),
                    .inverted => chip.IO[io].control.modify(.{
                        .func = .clock,
                        .output_override = .invert,
                        .oe_override = .force_high,
                    }),
                }
            }
        }
        if (self.disable_microtick) {
            chip.WATCHDOG.tick.modify(.{ .enabled = false });
            while (chip.WATCHDOG.tick.read().running) {}
        }
        if (self.disable_systick) {
            chip.SYSTICK.control_status.modify(.{ .count_enable = false });
        }
        if (self.change_microtick_divisor) |div| {
            chip.WATCHDOG.tick.modify(.{ .divisor = div });
        }
        if (self.change_systick_source) |src| {
            chip.SYSTICK.control_status.modify(.{ .clock_source = src });
        }
        if (self.change_systick_reload) |reload| {
            chip.SYSTICK.reload_value.write(.{ .value = reload });
        }
        if (self.enable_systick) {
            chip.SYSTICK.control_status.modify(.{
                .count_enable = true,
                .overflow_interrupt_enable = true,
            });
        }
        if (self.enable_microtick) {
            chip.WATCHDOG.tick.modify(.{ .enabled = true });
        }
        self.sys_pll.finish();
        self.usb_pll.finish();
        if (self.stop_xosc) {
            chip.XOSC.control.modify(.{ .enabled = .disabled });
        }
        if (self.stop_rosc) {
            chip.ROSC.control.modify(.{ .enabled = .disabled });
        }
    }

    fn setGlitchlessRefSource(comptime source: anytype) void {
        const ControlSource = std.meta.fieldInfo(@TypeOf(chip.CLOCKS.ref.control).Type, .source).type;
        const StatusSource = std.meta.fieldInfo(@TypeOf(chip.CLOCKS.ref.status).Type, .source).type;
        chip.CLOCKS.ref.control.modify(.{
            .source = std.enums.nameCast(ControlSource, source),
        });
        const expected_source = std.enums.nameCast(StatusSource, source);
        while (chip.CLOCKS.ref.status.read().source != expected_source) {}
    }

    fn setGlitchlessSysSource(comptime source: anytype) void {
        const ControlSource = std.meta.fieldInfo(@TypeOf(chip.CLOCKS.sys.control).Type, .source).type;
        const StatusSource = std.meta.fieldInfo(@TypeOf(chip.CLOCKS.sys.status).Type, .source).type;
        chip.CLOCKS.sys.control.modify(.{
            .source = std.enums.nameCast(ControlSource, source),
        });
        const expected_source = std.enums.nameCast(StatusSource, source);
        while (chip.CLOCKS.sys.status.read().source != expected_source) {}
    }
};

const RoscDivisor = std.meta.fieldInfo(@TypeOf(chip.ROSC.output_divisor).Type, .divisor).type;
fn encodeRoscDivisor(comptime divisor: comptime_int) RoscDivisor {
    return switch (divisor) {
        1...31 => @enumFromInt(0xAA0 + divisor),
        32 => .div32,
    };
}

pub fn init() void {
    const ch = comptime change: {
        var cc = ConfigChange {};
        const config = getConfig();

        if (config.xosc.frequency_hz == 0) {
            cc.stop_xosc = true;
        } else {
            cc.change_xosc_startup_delay_div256 = config.xosc.startup_delay_cycles / 256;
            cc.start_xosc = true;
            cc.wait_for_xosc_stable = true;
        }

        if (config.rosc.frequency_hz == 0) {
            cc.stop_rosc = true;
        } else {
            cc.change_rosc_divisor_early = encodeRoscDivisor(config.rosc.params.divisor);
            cc.start_rosc = .{ .enabled = .enabled };
            switch (config.rosc.params.range) {
                .low => |drive| {
                    cc.start_rosc.?.range = .low;
                    cc.change_rosc_drive0 = .{
                        .stage0 = drive[0],
                        .stage1 = drive[1],
                        .stage2 = drive[2],
                        .stage3 = drive[3],
                    };
                    cc.change_rosc_drive1 = .{
                        .stage4 = drive[4],
                        .stage5 = drive[5],
                        .stage6 = drive[6],
                        .stage7 = drive[7],
                    };
                },
                .medium => |drive| {
                    cc.start_rosc.?.range = .medium;
                    cc.change_rosc_drive0 = .{
                        .stage0 = drive[0],
                        .stage1 = drive[1],
                        .stage2 = drive[2],
                        .stage3 = drive[3],
                    };
                    cc.change_rosc_drive1 = .{
                        .stage4 = drive[4],
                        .stage5 = drive[5],
                    };
                },
                .high => |drive| {
                    cc.start_rosc.?.range = .high;
                    cc.change_rosc_drive0 = .{
                        .stage0 = drive[0],
                        .stage1 = drive[1],
                        .stage2 = drive[2],
                        .stage3 = drive[3],
                    };
                    cc.change_rosc_drive1 = .{};
                },
            }
            cc.wait_for_rosc_stable = true;
        }

        if (config.sys_pll.frequency_hz == 0) {
            cc.sys_pll.shutdown = true;
        } else {
            cc.sys_pll.disable_output_divisor = true;
            cc.sys_pll.change_input_divisor = config.sys_pll.vco.divisor;
            cc.sys_pll.change_multiplier = config.sys_pll.vco.multiplier;
            cc.sys_pll.wait_for_stable = true;
            cc.sys_pll.change_output_divisor = .{
                .divisor1 = config.sys_pll.output_divisor0,
                .divisor2 = config.sys_pll.output_divisor1,
            };
            cc.sys_pll.enable_output_divisor = true;
        }

        if (config.usb_pll.frequency_hz == 0) {
            cc.usb_pll.shutdown = true;
        } else {
            cc.usb_pll.disable_output_divisor = true;
            cc.usb_pll.change_input_divisor = config.usb_pll.vco.divisor;
            cc.usb_pll.change_multiplier = config.usb_pll.vco.multiplier;
            cc.usb_pll.wait_for_stable = true;
            cc.usb_pll.change_output_divisor = .{
                .divisor1 = config.usb_pll.output_divisor0,
                .divisor2 = config.usb_pll.output_divisor1,
            };
            cc.usb_pll.enable_output_divisor = true;
        }

        inline for (0.., config.gpin) |n, gpin| {
            if (gpin.frequency_hz == 0) {
                cc.setup_gpin_io[n] = .disabled;
            } else {
                cc.setup_gpin_io[n] = if (gpin.invert) .inverted else .normal;
                cc.gpin_hysteresis[n] = gpin.hysteresis;
                cc.setup_gpin_maintenance[n] = gpin.maintenance;
            }
        }

        switch (config.ref.source) {
            .rosc => {
                cc.switch_ref_to_rosc = true;
                cc.change_ref_divisor_mid = config.ref.integerDivisor();
            },
            .xosc => {
                cc.switch_ref_to_xosc = true;
                cc.change_ref_divisor_mid = config.ref.integerDivisor();
            },
            .usb_pll => {
                if (config.xosc.frequency_hz > 0) {
                    cc.switch_ref_to_xosc = true;
                } else {
                    cc.switch_ref_to_rosc = true;
                }
                cc.switch_ref_aux = .pll_usb;
                cc.switch_ref_to_aux = true;
                cc.change_ref_divisor_late = config.ref.integerDivisor();
            },
            .gpin0 => {
                if (config.xosc.frequency_hz > 0) {
                    cc.switch_ref_to_xosc = true;
                } else {
                    cc.switch_ref_to_rosc = true;
                }
                cc.switch_ref_aux = .gpin0;
                cc.switch_ref_to_aux = true;
                cc.change_ref_divisor_late = config.ref.integerDivisor();
            },
            .gpin1 => {
                if (config.xosc.frequency_hz > 0) {
                    cc.switch_ref_to_xosc = true;
                } else {
                    cc.switch_ref_to_rosc = true;
                }
                cc.switch_ref_aux = .gpin1;
                cc.switch_ref_to_aux = true;
                cc.change_ref_divisor_late = config.ref.integerDivisor();
            },
            else => unreachable,
        }

        if (config.sys.source == .ref) {
            cc.switch_sys_to_ref = true;
            cc.change_sys_divisor_ref = config.sys.divisor_256ths;
        } else {
            cc.switch_sys_to_ref = true;
            cc.switch_sys_aux = switch (config.sys.source) {
                .sys_pll => .pll_sys,
                .usb_pll => .pll_usb,
                .rosc => .rosc,
                .xosc => .xosc,
                .gpin0 => .gpin0,
                .gpin1 => .gpin1,
                else => unreachable,
            };
            cc.switch_sys_to_aux = true;
            cc.change_sys_divisor_late = config.sys.divisor_256ths;
        }

        if (config.microtick.frequency_hz == 0) {
            cc.disable_microtick = true;
        } else {
            std.debug.assert(config.microtick.source == .ref);
            cc.change_microtick_divisor = config.microtick.watchdog_cycles;
            cc.enable_microtick = true;
        }

        if (config.tick.frequency_hz == 0) {
            cc.disable_systick = true;
        } else {
            cc.change_systick_source = switch (config.tick.source) {
                .sys => .clk_sys,
                .microtick => .watchdog_tick,
                else => unreachable,
            };
            cc.change_systick_reload = config.tick.reload_value;
            cc.enable_systick = true;
        }

        if (config.uart_spi.frequency_hz == 0) {
            cc.disable_peri = true;
        } else {
            cc.enable_peri = switch (config.uart_spi.source) {
                .sys => .clk_sys,
                .sys_pll => .pll_sys,
                .usb_pll => .pll_usb,
                .rosc => .rosc,
                .xosc => .xosc,
                .gpin0 => .gpin0,
                .gpin1 => .gpin1,
                else => unreachable,
            };
        }

        if (config.usb.frequency_hz == 0) {
            cc.disable_usb = true;
        } else {
            cc.change_usb_divisor = config.usb.integerDivisor();
            cc.enable_usb = switch (config.usb.source) {
                .sys_pll => .pll_usb,
                .usb_pll => .pll_sys,
                .rosc => .rosc,
                .xosc => .xosc,
                .gpin0 => .gpin0,
                .gpin1 => .gpin1,
                else => unreachable,
            };
        }

        if (config.adc.frequency_hz == 0) {
            cc.disable_adc = true;
        } else {
            cc.change_adc_divisor = config.adc.integerDivisor();
            cc.enable_adc = switch (config.adc.source) {
                .sys_pll => .pll_usb,
                .usb_pll => .pll_sys,
                .rosc => .rosc,
                .xosc => .xosc,
                .gpin0 => .gpin0,
                .gpin1 => .gpin1,
                else => unreachable,
            };
        }

        if (config.rtc.frequency_hz == 0) {
            cc.disable_rtc = true;
        } else {
            cc.change_rtc_divisor = config.rtc.divisor_256ths;
            cc.enable_rtc = switch (config.rtc.source) {
                .sys_pll => .pll_usb,
                .usb_pll => .pll_sys,
                .rosc => .rosc,
                .xosc => .xosc,
                .gpin0 => .gpin0,
                .gpin1 => .gpin1,
                else => unreachable,
            };
        }

        inline for (0.., config.gpout) |n, gpout| {
            if (gpout.generator.frequency_hz == 0) {
                cc.disable_gpout[n] = true;
                cc.setup_gpout_io[n] = .disabled;
            } else {
                var ctrl: std.meta.fieldInfo(chip.reg_types.clk.GpoutClockGenerator, .control).type = .{
                    .source = switch (gpout.generator.source) {
                        .sys_pll => .pll_sys,
                        .gpin0 => .gpin0,
                        .gpin1 => .gpin1,
                        .usb_pll => .pll_usb,
                        .rosc => .rosc,
                        .xosc => .xosc,
                        .sys => .clk_sys,
                        .usb => .clk_usb,
                        .adc => .clk_adc,
                        .rtc => .clk_rtc,
                        .ref => .clk_ref,
                        else => unreachable,
                    },
                };
                cc.change_gpout_divisor = gpout.generator.divisor_256ths;
                cc.change_gpout_control[n] = ctrl;
                ctrl.enabled = true;
                cc.enable_gpout[n] = ctrl;
                cc.setup_gpout_io[n] = if (gpout.invert) .inverted else .normal;
                cc.setup_gpout_slew[n] = gpout.slew;
                cc.setup_gpout_strength[n] = gpout.strength;
            }
        }

        break :change cc;
    };
    ch.run();
}

pub fn applyConfig(comptime config: anytype, comptime previous_config: anytype) void {
    const parsed = comptime if (@TypeOf(config) == ParsedConfig) config else parseConfig(config);
    const previous_parsed = comptime if (@TypeOf(previous_config) == ParsedConfig) previous_config else parseConfig(previous_config);
    applyParsedConfig(parsed, previous_parsed);
}

fn applyParsedConfig(comptime parsed: ParsedConfig, comptime old: ParsedConfig) void {
    _ = old;
    _ = parsed;
    comptime change: {
        var cc = ConfigChange {};

        // TODO

        break :change cc;
    }.run();
}
