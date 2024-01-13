pub const ROSC_Params = struct {
    range: union(enum) {
        low: [8]chip.reg_types.clk.ROSC_Stage_Drive_Strength,
        medium: [6]chip.reg_types.clk.ROSC_Stage_Drive_Strength,
        high: [4]chip.reg_types.clk.ROSC_Stage_Drive_Strength,
    },
    divisor: comptime_int, // 1 - 32

    pub const default: ROSC_Params = .{
        .range = .{ .low = .{
            .@"1x", .@"1x", .@"1x", .@"1x",
            .@"1x", .@"1x", .@"1x", .@"1x",
        }},
        .divisor = 16,
    };
};

pub const ROSC_Config = union(enum) {
    // This will not be very accurate, depends heavily on process/voltage/temperature
    frequency_hz: comptime_int,
    manual: ROSC_Params,
};

pub const Config = struct {
    rosc: ?ROSC_Config = null,

    xosc: ?struct {
        /// Depends on crystal; typically 12 MHz for compatibility with USB boot ROM
        frequency_hz: comptime_int = 12_000_000,
        startup_delay_cycles: comptime_int = 50_000,
    } = null,

    sys_pll: ?PLL_Config = null,
    usb_pll: ?PLL_Config = null,

    gpin: [2]?struct {
        pad: chip.Pad_ID,
        invert: bool,
        hysteresis: bool,
        maintenance: chip.reg_types.io.Pin_Maintenance,
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
        pad: chip.Pad_ID,
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
        slew: chip.reg_types.io.Slew_Rate,
        strength: chip.reg_types.io.Drive_Strength,
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
        source: ?USB_ADC_RTC_Source = null,
        frequency_hz: comptime_int = 48_000_000,
    } = null,

    adc: ?struct {
        source: ?USB_ADC_RTC_Source = null,
        frequency_hz: comptime_int = 48_000_000,
    } = null,

    rtc: ?struct {
        source: USB_ADC_RTC_Source,
        frequency_hz: comptime_int,
    } = null,

    // TODO sys clock resuscitation config
    // TODO watchdog timeout config
};

pub const USB_ADC_RTC_Source = enum {
    sys_pll,
    usb_pll,
    rosc,
    xosc,
    gpin0,
    gpin1,
};

pub const Generic_Source = enum {
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

    pub fn get_frequency_from_config(comptime self: Generic_Source, comptime parsed: Parsed_Config) comptime_int {
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

pub const Generic_Clock_Generator_Config = struct {
    source: Generic_Source,
    divisor_256ths: comptime_int,
    frequency_hz: comptime_int,
    period_ns: comptime_int,

    pub fn init(comptime source: Generic_Source, comptime target_frequency_hz: comptime_int, comptime fractional_divisor: bool, comptime parsed: Parsed_Config) Generic_Clock_Generator_Config {
        const source_frequency_hz = source.get_frequency_from_config(parsed);
        if (source_frequency_hz == 0) {
            @compileError("Source clock is disabled");
        }

        var divisor_256ths = util.div_round(source_frequency_hz * 256, target_frequency_hz);
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
        const frequency_hz = util.div_round(source_frequency_hz * 256, divisor_256ths);
        if (frequency_hz != target_frequency_hz) {
            @compileError(std.fmt.comptimePrint("Cannot achieve clock generator target frequency {}; closest possible is {}", .{
                util.fmt_frequency(target_frequency_hz),
                util.fmt_frequency(frequency_hz),
            }));
        }

        return .{
            .source = source,
            .divisor_256ths = divisor_256ths,
            .frequency_hz = frequency_hz,
            .period_ns = util.div_round(1_000_000_000, frequency_hz),
        };
    }

    pub fn integer_divisor(comptime self: Generic_Clock_Generator_Config) chip.reg_types.clk.Div123 {
        return switch (self.divisor_256ths) {
            0x100 => .none,
            0x200 => .div2,
            0x300 => .div3,
            else => unreachable,
        };
    }

    pub fn is_fractional_divisor(self: Generic_Clock_Generator_Config) bool {
        return (self.divisor_256ths & 0xFF) != 0;
    }

    pub fn should_use_duty_cycle_correction(self: Generic_Clock_Generator_Config) bool {
        return self.divisor_256ths >= 0x300 and !self.is_fractional_divisor();
    }

    pub const default: Generic_Clock_Generator_Config = .{
        .source = .rosc,
        .divisor_256ths = 256,
        .frequency_hz = 0,
        .period_ns = 0,
    };
};

pub const Parsed_Config = struct {
    xosc: struct {
        /// Depends on crystal; typically 12 MHz for compatibility with USB boot ROM
        frequency_hz: comptime_int,
        period_ns: comptime_int,
        startup_delay_cycles: comptime_int = 50_000,
    },
    rosc: struct {
        frequency_hz: comptime_int,
        period_ns: comptime_int,
        params: ROSC_Params,
    },
    sys_pll: Parsed_PLL_Config,
    usb_pll: Parsed_PLL_Config,
    gpin: [2]struct {
        pad: chip.Pad_ID,
        invert: bool,
        hysteresis: bool,
        maintenance: chip.reg_types.io.Pin_Maintenance,
        frequency_hz: comptime_int,
        period_ns: comptime_int,
    },
    ref: Generic_Clock_Generator_Config,
    sys: Generic_Clock_Generator_Config,
    microtick: struct {
        source: Generic_Source,
        period_ns: comptime_int,
        frequency_hz: comptime_int,
        watchdog_cycles: comptime_int,
    },
    tick: struct {
        source: Generic_Source,
        period_ns: comptime_int,
        frequency_hz: comptime_int,
        reload_value: comptime_int,
    },
    uart_spi: Generic_Clock_Generator_Config,
    usb: Generic_Clock_Generator_Config,
    adc: Generic_Clock_Generator_Config,
    rtc: Generic_Clock_Generator_Config,
    gpout: [4]struct {
        pad: chip.Pad_ID,
        invert: bool,
        slew: chip.reg_types.io.Slew_Rate,
        strength: chip.reg_types.io.Drive_Strength,
        generator: Generic_Clock_Generator_Config,
    },
};

pub fn get_config() Parsed_Config {
    return comptime if (@hasDecl(root, "clocks")) parse_config(root.clocks) else reset_config;
}

pub const reset_config = parse_config(.{
    .rosc = .{ .manual = ROSC_Params.default },
});

pub fn parse_config(comptime config: Config) Parsed_Config {
    return comptime done: {
        var parsed = Parsed_Config{
            .rosc = .{
                .frequency_hz = 0,
                .period_ns = 0,
                .params = ROSC_Params.default,
            },
            .xosc = .{
                .frequency_hz = 0,
                .period_ns = 0,
            },
            .sys_pll = Parsed_PLL_Config.disabled,
            .usb_pll = Parsed_PLL_Config.disabled,
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
            .ref = Generic_Clock_Generator_Config.default,
            .sys = Generic_Clock_Generator_Config.default,
            .uart_spi = Generic_Clock_Generator_Config.default,
            .usb = Generic_Clock_Generator_Config.default,
            .adc = Generic_Clock_Generator_Config.default,
            .rtc = Generic_Clock_Generator_Config.default,
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
            parsed.rosc.period_ns = util.div_round(1_000_000_000, parsed.rosc.frequency_hz);
        }

        if (config.xosc) |xosc| {
            parsed.xosc.frequency_hz = xosc.frequency_hz;
            parsed.xosc.period_ns = util.div_round(1_000_000_000, xosc.frequency_hz);
            parsed.xosc.startup_delay_cycles = (xosc.startup_delay_cycles / 256) * 256;
            if (xosc.frequency_hz < 1_000_000) @compileError("XOSC frequency should be at least 1 MHz");
            if (xosc.frequency_hz > 50_000_000) @compileError("XOSC frequency should be <= 50 MHz (15 MHz if using a crystal)");
        }

        if (config.sys_pll) |pll| {
            parsed.sys_pll = parse_pll_config(pll, parsed.xosc.frequency_hz);
        }

        if (config.usb_pll) |pll| {
            parsed.usb_pll = parse_pll_config(pll, parsed.xosc.frequency_hz);
        }

        for (0..2) |n| {
            if (config.gpin[n]) |gpin| {
                const io: chip.Pad_ID = switch (n) {
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
                    .period_ns = util.div_round(1_000_000_000, gpin.frequency_hz),
                };
                check_frequency("GPIN", parsed.gpin[n].frequency_hz, 1, 50_000_000);
            }
        }

        const ref_source: Generic_Source = src: {
            if (config.ref.source) |source| {
                break :src std.enums.nameCast(Generic_Source, @tagName(source));
            }
            break :src if (parsed.xosc.frequency_hz > 0) .xosc else .rosc;
        };
        const ref_source_freq = ref_source.get_frequency_from_config(parsed);
        if (ref_source_freq == 0) @compileError(std.fmt.comptimePrint("Ref clock source (.{s}) is not configured!", .{ @tagName(ref_source) }));
        parsed.ref = Generic_Clock_Generator_Config.init(ref_source, config.ref.frequency_hz orelse ref_source_freq, false, parsed);
        check_frequency("ref", parsed.ref.frequency_hz, 1, 133_000_000);

        const sys_source: Generic_Source = src: {
            if (config.sys.source) |source| {
                break :src std.enums.nameCast(Generic_Source, @tagName(source));
            }
            if (parsed.sys_pll.frequency_hz > 0) break :src .sys_pll;
            break :src if (parsed.xosc.frequency_hz > 0) .xosc else .rosc;
        };
        const sys_source_freq = sys_source.get_frequency_from_config(parsed);
        if (sys_source_freq == 0) @compileError(std.fmt.comptimePrint("Sys clock source (.{s}) is not configured!", .{ @tagName(sys_source) }));
        parsed.sys = Generic_Clock_Generator_Config.init(sys_source, config.sys.frequency_hz orelse sys_source.get_frequency_from_config(parsed), true, parsed);
        check_frequency("sys", parsed.sys.frequency_hz, 1, 133_000_000);

        {
            parsed.microtick.source = std.enums.nameCast(Generic_Source, @tagName(config.microtick.source));
            const source_frequency_hz = parsed.microtick.source.get_frequency_from_config(parsed);

            parsed.microtick.period_ns = config.microtick.period_ns;
            const divisor = util.div_round(source_frequency_hz * parsed.microtick.period_ns, 1_000_000_000);
            if (divisor == 0) {
                @compileError(std.fmt.comptimePrint("Ref clock ({}) too slow for microtick period ({} ns)", .{
                    util.fmt_frequency(source_frequency_hz),
                    parsed.microtick.period_ns,
                }));
            } else if (divisor >= 512) {
                @compileError(std.fmt.comptimePrint("Ref clock ({}) too fast for microtick priod ({} ns); div={}!", .{
                    util.fmt_frequency(source_frequency_hz),
                    parsed.microtick.period_ns,
                    divisor,
                }));
            }

            parsed.microtick.watchdog_cycles = divisor;
            parsed.microtick.frequency_hz = util.div_round(source_frequency_hz, divisor);
            
            const actual_period = util.div_round(divisor * 1_000_000_000, parsed.ref.frequency_hz);
                if (actual_period != parsed.microtick.period_ns) {
                    @compileError(std.fmt.comptimePrint("Invalid microtick period; closest match is {} ns ({} cycles, {} microtick, {} source clock)", .{
                        actual_period,
                        divisor,
                        util.fmt_frequency(parsed.microtick.frequency_hz),
                        util.fmt_frequency(source_frequency_hz),
                    }));
                }
            check_frequency("microtick", parsed.microtick.frequency_hz, 1, 133_000_000);
        }

        if (config.tick) |tick| {
            parsed.tick.source = std.enums.nameCast(Generic_Source, @tagName(tick.source));
            const source_frequency_hz = parsed.tick.source.get_frequency_from_config(parsed);

            parsed.tick.period_ns = tick.period_ns;
            var cycles_per_interrupt = util.div_round(source_frequency_hz * tick.period_ns, 1_000_000_000);

            // systick interrupt only fires if RELOAD is > 0, and RELOAD is cycles_per_interrupt - 1,
            cycles_per_interrupt = @max(2, cycles_per_interrupt);

            const actual_freq = util.div_round(source_frequency_hz, cycles_per_interrupt);
            const actual_period = util.div_round(cycles_per_interrupt * 1_000_000_000, source_frequency_hz);
            if (actual_period != tick.period_ns) {
                @compileError(std.fmt.comptimePrint("Invalid tick period; closest match is {} ns ({} cycles per interrupt, {} tick, {} source clock)", .{
                    actual_period,
                    cycles_per_interrupt,
                    util.fmt_frequency(actual_freq),
                    util.fmt_frequency(source_frequency_hz),
                }));
            }
            parsed.tick.frequency_hz = actual_freq;
            parsed.tick.reload_value = cycles_per_interrupt - 1;
            check_frequency("tick", parsed.tick.frequency_hz, 1, 1_000_000);
        }

        if (config.uart_spi) |uart_spi| {
            const source = std.enums.nameCast(Generic_Source, @tagName(uart_spi.source));
            parsed.uart_spi = Generic_Clock_Generator_Config.init(source, source.get_frequency_from_config(parsed), false, parsed);
            check_frequency("UART/SPI", parsed.uart_spi.frequency_hz, 1, 133_000_000);
        }

        if (config.usb) |usb| {
            const source: Generic_Source = src: {
                if (usb.source) |source| {
                    break :src std.enums.nameCast(Generic_Source, @tagName(source));
                }
                break :src if (parsed.usb_pll.frequency_hz > 0) .usb_pll else .sys_pll;
            };
            parsed.usb = Generic_Clock_Generator_Config.init(source, usb.frequency_hz, false, parsed);
            check_frequency("USB", parsed.usb.frequency_hz, 47_999_000, 48_001_000);
        }

        if (config.adc) |adc| {
            const source: Generic_Source = src: {
                if (adc.source) |source| {
                    break :src std.enums.nameCast(Generic_Source, @tagName(source));
                }
                break :src if (parsed.usb_pll.frequency_hz > 0) .usb_pll else .sys_pll;
            };
            parsed.usb = Generic_Clock_Generator_Config.init(source, adc.frequency_hz, false, parsed);
            check_frequency("ADC", parsed.adc.frequency_hz, 47_990_000, 48_010_000);
        }

        if (config.rtc) |rtc| {
            const source = std.enums.nameCast(Generic_Source, @tagName(rtc.source));
            parsed.usb = Generic_Clock_Generator_Config.init(source, rtc.frequency_hz, true, parsed);
            check_frequency("RTC", parsed.rtc.frequency_hz, 1, 65536);
        }

        for (0.., config.gpout, &parsed.gpout) |n, maybe_gpout, *parsed_gpout| {
            if (maybe_gpout) |gpout| {
                const io: chip.Pad_ID = switch (n) {
                    0 => .GPIO21,
                    1 => .GPIO23,
                    2 => .GPIO24,
                    3 => .GPIO25,
                    else => unreachable,
                };
                if (gpout.pad != io) {
                    @compileError(std.fmt.comptimePrint("Expected pad {s} for GP clock output {}", .{ @tagName(io), n }));
                }

                const source = std.enums.nameCast(Generic_Source, @tagName(gpout.source));
                parsed_gpout.pad = gpout.pad;
                parsed_gpout.invert = gpout.invert;
                parsed_gpout.slew = gpout.slew;
                parsed_gpout.strength = gpout.strength;
                parsed_gpout.generator = Generic_Clock_Generator_Config.init(source, source.get_frequency_from_config(parsed), true, parsed);

                check_frequency("GPOUT", parsed_gpout.frequency_hz, 1, 50_000_000);
            }
        }

        break :done parsed;
    };
}

pub const PLL_Config = struct {
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

pub const Parsed_PLL_Config = struct {
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

    pub const disabled = Parsed_PLL_Config {
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

pub fn parse_pll_config(comptime config: PLL_Config, comptime xosc_frequency_hz: comptime_int) Parsed_PLL_Config {
    if (config.frequency_hz == 0) @compileError("PLL output frequency must be > 0; use .sys_pll = null or .usb_pll = null to disable");

    return switch (config.vco) {
        .auto => pll_params_auto(.{
            .xosc_frequency_hz = xosc_frequency_hz,
            .out_frequency_hz = config.frequency_hz,
        }),
        .frequency_hz => |vco_freq| pll_params_explicit_vco(.{
            .xosc_frequency_hz = xosc_frequency_hz,
            .vco_frequency_hz = vco_freq,
            .out_frequency_hz = config.frequency_hz,
        }),
        .manual => |params| pll_params_manual(.{
            .xosc_frequency_hz = xosc_frequency_hz,
            .divisor = params.divisor,
            .multiplier = params.multiplier,
            .out_frequency_hz = config.frequency_hz,
        }),
    };
}

pub const PLL_Params_Manual_Options = struct {
    xosc_frequency_hz: comptime_int,
    divisor: comptime_int,
    multiplier: comptime_int,
    out_frequency_hz: comptime_int,
};
pub fn pll_params_manual(comptime options: PLL_Params_Manual_Options) Parsed_PLL_Config {
    @setEvalBranchQuota(1_000_000);
    return comptime done: {
        if (options.xosc_frequency_hz < 5_000_000) @compileError("XOSC frequency must be >= 5 MHz when using PLLs");
        if (options.divisor < 1) @compileError("PLL input divisor must be >= 1");
        if (options.divisor > 63) @compileError("PLL input divisor must be <= 63");

        if (options.multiplier < 16) @compileError("PLL multiplier must be >= 16");
        if (options.multiplier > 320) @compileError("PLL multiplier must be <= 320");

        var config = Parsed_PLL_Config {
            .vco = .{
                .divisor = options.divisor,
                .multiplier = options.multiplier,
                .frequency_hz = util.div_round(options.xosc_frequency_hz * options.multiplier, options.divisor),
                .period_ns = 0,
            },
            .output_divisor0 = 1,
            .output_divisor1 = 1,
            .frequency_hz = 0,
            .period_ns = 0,
        };

        config.vco.period_ns = util.div_round(1_000_000_000, config.vco.frequency_hz);

        check_frequency("VCO", config.vco.frequency_hz, 750_000_000, 1_600_000_000);
        find_pll_output_divisors(&config, options.out_frequency_hz);

        break :done config;
    };
}

fn find_pll_output_divisors(comptime config: *Parsed_PLL_Config, comptime out_frequency_hz: comptime_int) void {
    comptime done: {
        var closest_match_freq = 0;
        var closest_low_match_freq = 0;
        for (1..8) |divisor0| {
            const f0 = util.div_round(config.vco.frequency_hz, divisor0);
            if (f0 < closest_low_match_freq) break;

            for (1 .. divisor0 + 1) |divisor1| {
                const f1 = util.div_round(f0, divisor1);

                if (f1 == out_frequency_hz) {
                    config.output_divisor0 = divisor0;
                    config.output_divisor1 = divisor1;
                    config.frequency_hz = f1;
                    config.period_ns = util.div_round(1_000_000_000, f1);
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
            util.fmt_frequency(out_frequency_hz),
            util.fmt_frequency(closest_match_freq),
            error_ppm,
        }));
    }
}

pub const PLL_Params_Explicit_VCO_Options = struct {
    xosc_frequency_hz: comptime_int,
    vco_frequency_hz: comptime_int,
    out_frequency_hz: comptime_int,
};
pub fn pll_params_explicit_vco(comptime options: PLL_Params_Explicit_VCO_Options) Parsed_PLL_Config {
    @setEvalBranchQuota(1_000_000);
    return comptime done: {
        var closest_match_freq = 0;
        for (1..64) |divisor| {
            const input = util.div_round(options.xosc_frequency_hz, options.divisor);
            if (input < 5_000_000) break;

            for (16..321) |multiplier| {
                const vco = input * multiplier;

                if (vco > 1_600_000_000) break;
                if (vco < 750_000_000) continue;

                if (vco == options.vco_frequency_hz) {
                    break :done pll_params_manual(options.xosc_frequency_hz, divisor, multiplier, options.out_frequency_hz);
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
            util.fmt_frequency(options.vco_frequency_hz),
            util.fmt_frequency(closest_match_freq),
            error_ppm,
        }));
    };
}

pub const PLL_Params_Auto_Options = struct {
    xosc_frequency_hz: comptime_int,
    min_vco_frequency_hz: comptime_int = 750_000_000,
    max_vco_frequency_hz: comptime_int = 1_600_000_000,
    out_frequency_hz: comptime_int,
};
pub fn pll_params_auto(comptime options: PLL_Params_Auto_Options) Parsed_PLL_Config {
    @setEvalBranchQuota(1_000_000);
    return comptime done: {
        if (options.xosc_frequency_hz < 5_000_000) @compileError("XOSC frequency must be >= 5 MHz when using PLLs");
        if (options.min_vco_frequency_hz < 750_000_000) @compileError("Minimum VCO frequency is 750 MHz");
        if (options.max_vco_frequency_hz > 1_600_000_000) @compileError("Maximum VCO frequency is 1600 MHz");

        var closest_match: ?Parsed_PLL_Config = null;
        var closest_low_match_freq = 0;
        for (1..64) |divisor| {
            const input = util.div_round(options.xosc_frequency_hz, divisor);
            if (input < 5_000_000) break;

            for (16..321) |multiplier| {
                const vco = input * multiplier;

                if (vco > options.max_vco_frequency_hz) break;
                if (vco < options.min_vco_frequency_hz) continue;

                for (1..8) |divisor0| {
                    const f0 = util.div_round(vco, divisor0);
                    if (f0 < closest_low_match_freq) break;

                    for (1 .. divisor0 + 1) |divisor1| {
                        const f1 = util.div_round(f0, divisor1);

                        if (f1 == options.out_frequency_hz) {
                            break :done .{
                                .vco = .{
                                    .divisor = divisor,
                                    .multiplier = multiplier,
                                    .frequency_hz = vco,
                                    .period_ns = util.div_round(1_000_000_000, vco),
                                },
                                .output_divisor0 = divisor0,
                                .output_divisor1 = divisor1,
                                .frequency_hz = f1,
                                .period_ns = util.div_round(1_000_000_000, f1),
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
                                .period_ns = util.div_round(1_000_000_000, vco),
                            },
                            .output_divisor0 = divisor0,
                            .output_divisor1 = divisor1,
                            .frequency_hz = f1,
                            .period_ns = util.div_round(1_000_000_000, f1),
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
                util.fmt_frequency(options.out_frequency_hz),
                util.fmt_frequency(options.xosc_frequency_hz),
                util.fmt_frequency(util.div_round(options.xosc_frequency_hz, closest.vco.divisor)),
                closest.vco.divisor,
                util.fmt_frequency(closest.vco.frequency_hz),
                closest.vco.multiplier,
                closest.output_divisor0,
                closest.output_divisor1,
                util.fmt_frequency(closest.frequency_hz),
                error_ppm,
            }));
        } else {
            @compileError(std.fmt.comptimePrint("Can't generate PLL frequency: {}", .{ util.fmt_frequency(options.out_frequency_hz) }));
        }
    };
}

fn check_frequency(comptime name: []const u8, comptime freq: comptime_int, comptime min: comptime_int, comptime max: comptime_int) void {
    comptime {
        if (freq < min) {
            invalid_frequency(name, freq, ">=", min);
        } else if (freq > max) {
            invalid_frequency(name, freq, "<=", max);
        }
    }
}

fn invalid_frequency(comptime name: []const u8, comptime actual: comptime_int, comptime dir: []const u8, comptime limit: comptime_int) void {
    comptime {
        @compileError(std.fmt.comptimePrint("Invalid {s} frequency: {}; must be {s} {}", .{
            name, util.fmt_frequency(actual),
            dir,  util.fmt_frequency(limit),
        }));
    }
}

pub fn print_config(comptime config: Parsed_Config, writer: anytype) !void {
    try writer.writeAll("\nXOSC\n");
    try writer.writeAll(std.fmt.comptimePrint("   Startup:    {} cycles\n", .{ config.xosc.startup_delay_cycles }));
    try writer.writeAll(std.fmt.comptimePrint("   Frequency: {}\n", .{ comptime util.fmt_frequency(config.xosc.frequency_hz) }));
    try writer.writeAll(std.fmt.comptimePrint("   Period:    {} ns\n", .{ config.xosc.period_ns }));

    try writer.writeAll("\nROSC\n");
    switch (config.rosc.params.range) {
        .low => |str| inline for (0.., str) |i, s| {
            try writer.writeAll(std.fmt.comptimePrint("   Drive {}:  {s}\n", .{ i, @tagName(s) }));
        },
        .medium => |str| inline for (0.., str) |i, s| {
            try writer.writeAll(std.fmt.comptimePrint("   Drive {}:  {s}\n", .{ i, @tagName(s) }));
        },
        .high => |str| inline for (0.., str) |i, s| {
            try writer.writeAll(std.fmt.comptimePrint("   Drive {}:  {s}\n", .{ i, @tagName(s) }));
        },
    }
    try writer.writeAll(std.fmt.comptimePrint("   Divisor:   {}\n", .{ config.rosc.params.divisor }));
    try writer.writeAll(std.fmt.comptimePrint("   Frequency: {}\n", .{ comptime util.fmt_frequency(config.rosc.frequency_hz) }));
    try writer.writeAll(std.fmt.comptimePrint("   Period:    {} ns\n", .{ config.rosc.period_ns }));

    try writer.writeAll("\nSys PLL\n");
    try print_pll_config(config.sys_pll, writer);

    try writer.writeAll("\nUSB PLL\n");
    try print_pll_config(config.usb_pll, writer);

    inline for (0.., config.gpin) |i, gpin| {
        try writer.writeAll(std.fmt.comptimePrint("\nGPIN{}\n", .{ i }));
        try writer.writeAll(std.fmt.comptimePrint("   Pad:       {s}\n", .{ @tagName(gpin.pad) }));
        try writer.writeAll(std.fmt.comptimePrint("   Invert:    {}\n", .{ gpin.invert }));
        try writer.writeAll(std.fmt.comptimePrint("   Hyst:      {}\n", .{ gpin.hysteresis }));
        try writer.writeAll(std.fmt.comptimePrint("   Term:      {s}\n", .{ @tagName(gpin.maintenance) }));
        try writer.writeAll(std.fmt.comptimePrint("   Frequency: {}\n", .{ comptime util.fmt_frequency(gpin.frequency_hz) }));
        try writer.writeAll(std.fmt.comptimePrint("   Period:    {} ns\n", .{ gpin.period_ns }));
    }

    try writer.writeAll("\nRef\n");
    try print_generic_clock_generator_config(config.ref, writer);

    try writer.writeAll("\nSys\n");
    try print_generic_clock_generator_config(config.sys, writer);

    try writer.writeAll("\nMicrotick\n");
    try writer.writeAll(std.fmt.comptimePrint("   Source:    {s}\n", .{ @tagName(config.microtick.source) }));
    try writer.writeAll(std.fmt.comptimePrint("   WD Cycles: {}\n", .{ config.microtick.watchdog_cycles }));
    try writer.writeAll(std.fmt.comptimePrint("   Frequency: {}\n", .{ comptime util.fmt_frequency(config.microtick.frequency_hz) }));
    try writer.writeAll(std.fmt.comptimePrint("   Period:    {} ns\n", .{ config.microtick.period_ns }));

    try writer.writeAll("\nTick\n");
    try writer.writeAll(std.fmt.comptimePrint("   Source:    {s}\n", .{ @tagName(config.tick.source) }));
    try writer.writeAll(std.fmt.comptimePrint("   Reload:    {}\n", .{ config.tick.reload_value }));
    try writer.writeAll(std.fmt.comptimePrint("   Frequency: {}\n", .{ comptime util.fmt_frequency(config.tick.frequency_hz) }));
    try writer.writeAll(std.fmt.comptimePrint("   Period:    {} ns\n", .{ config.tick.period_ns }));

    try writer.writeAll("\nUART/SPI\n");
    try print_generic_clock_generator_config(config.uart_spi, writer);

    try writer.writeAll("\nUSB\n");
    try print_generic_clock_generator_config(config.usb, writer);

    try writer.writeAll("\nADC\n");
    try print_generic_clock_generator_config(config.adc, writer);

    try writer.writeAll("\nRTC\n");
    try print_generic_clock_generator_config(config.rtc, writer);

    inline for (0.., config.gpout) |i, gpout| {
        try writer.writeAll(std.fmt.comptimePrint("\nGPOUT{}\n", .{ i }));
        try writer.writeAll(std.fmt.comptimePrint("   Pad:       {s}\n", .{ @tagName(gpout.pad) }));
        try writer.writeAll(std.fmt.comptimePrint("   Invert:    {}\n", .{ gpout.invert }));
        try writer.writeAll(std.fmt.comptimePrint("   Slew:      {s}\n", .{ @tagName(gpout.slew) }));
        try writer.writeAll(std.fmt.comptimePrint("   Strength:  {s}\n", .{ @tagName(gpout.strength) }));
        try print_generic_clock_generator_config(gpout.generator, writer);
    }
}

fn print_generic_clock_generator_config(comptime config: Generic_Clock_Generator_Config, writer: anytype) !void {
    try writer.writeAll(std.fmt.comptimePrint("   Source:    {s}\n", .{ @tagName(config.source) }));
    try writer.writeAll(std.fmt.comptimePrint("   Divisor:   {} + {}/256\n", .{ config.divisor_256ths >> 8, config.divisor_256ths & 0xFF }));
    try writer.writeAll(std.fmt.comptimePrint("   Frequency: {}\n", .{ comptime util.fmt_frequency(config.frequency_hz) }));
    try writer.writeAll(std.fmt.comptimePrint("   Period:    {} ns\n", .{ config.period_ns }));
}

fn print_pll_config(comptime config: Parsed_PLL_Config, writer: anytype) !void {
    try writer.writeAll(std.fmt.comptimePrint("   Input Divisor:    {}\n", .{ config.vco.divisor }));
    try writer.writeAll(std.fmt.comptimePrint("   VCO Multiplier:   {}\n", .{ config.vco.multiplier }));
    try writer.writeAll(std.fmt.comptimePrint("   VCO Frequency:    {}\n", .{ comptime util.fmt_frequency(config.vco.frequency_hz) }));
    try writer.writeAll(std.fmt.comptimePrint("   VCO Period:       {} ns\n", .{ config.vco.period_ns }));
    try writer.writeAll(std.fmt.comptimePrint("   Output Divisor 1: {}\n", .{ config.output_divisor0 }));
    try writer.writeAll(std.fmt.comptimePrint("   Output Divisor 2: {}\n", .{ config.output_divisor1 }));
    try writer.writeAll(std.fmt.comptimePrint("   Output Frequency: {}\n", .{ comptime util.fmt_frequency(config.frequency_hz) }));
    try writer.writeAll(std.fmt.comptimePrint("   Output Period:    {} ns\n", .{ config.period_ns }));
}



const PLL_Config_Change = struct {
    pll: *volatile chip.reg_types.clk.PLL,

    disable_output_divisor: bool = false,
    change_input_divisor: ?u6 = null,
    change_multiplier: ?u12 = null,
    should_wait_for_stable: bool = false,
    change_output_divisor: ?@TypeOf(chip.PLL_SYS.output).Type = null,
    enable_output_divisor: bool = false,
    shutdown: bool = false,

    pub fn init(comptime self: PLL_Config_Change) void {
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

    pub fn wait_for_stable(comptime self: PLL_Config_Change) void {
        if (self.should_wait_for_stable) {
            while (!self.pll.control_status.read().locked) {}
        }
        if (self.change_output_divisor) |div| {
            self.pll.output.write(div);
        }
        if (self.enable_output_divisor) {
            self.pll.power.write(.run);
        }
    }

    pub fn finish(comptime self: PLL_Config_Change) void {
        if (self.shutdown) {
            self.pll.power.write(.shutdown);
        }
    }
};

/// This contains all the steps that might potentially be necessary to change
/// from one Parsed_Config to another, or to set up the initial Parsed_Config.
/// It's generated at comptime so that the run() function optimizes to just the necessary operations.
const Config_Change = struct {
    resets_to_clear: ?chip.reg_types.sys.Reset_Bitmap = null,
    change_xosc_startup_delay_div256: ?u14 = null,
    start_xosc: bool = false,

    change_rosc_divisor_early: ?ROSC_Divisor = null,
    change_rosc_drive0: ?@TypeOf(chip.ROSC.drive0).Type = null,
    change_rosc_drive1: ?@TypeOf(chip.ROSC.drive1).Type = null,
    start_rosc: ?@TypeOf(chip.ROSC.control).Type = null,
    change_rosc_divisor_late: ?ROSC_Divisor = null,

    wait_for_rosc_stable: bool = false,
    wait_for_xosc_stable: bool = false,

    disable_gpout: [4]bool = .{ false, false, false, false },
    disable_peri: bool = false,
    disable_usb: bool = false,
    disable_adc: bool = false,
    disable_rtc: bool = false,
    cycles_to_wait_after_disables: u32 = 0,

    setup_gpin_hysteresis: [2]?bool = .{ null, null },
    setup_gpin_maintenance: [2]?chip.reg_types.io.Pin_Maintenance = .{ null, null },
    setup_gpin_io: [2]?enum { disabled, normal, inverted } = .{ null, null },

    change_ref_divisor_early: ?chip.reg_types.clk.Div123 = null,
    change_sys_divisor_early: ?u32 = null,
    switch_ref_to_rosc: bool = false,
    switch_ref_to_xosc: bool = false,
    change_ref_divisor_mid: ?chip.reg_types.clk.Div123 = null,

    switch_sys_to_ref: bool = false,
    change_sys_divisor_ref: ?u32 = null,

    sys_pll: PLL_Config_Change = .{ .pll = chip.PLL_SYS },
    usb_pll: PLL_Config_Change = .{ .pll = chip.PLL_USB },

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

    setup_gpout_slew: [4]?chip.reg_types.io.Slew_Rate = .{ null, null, null, null },
    setup_gpout_strength: [4]?chip.reg_types.io.Drive_Strength = .{ null, null, null, null },
    setup_gpout_io: [4]?enum { disabled, normal, inverted } = .{ null, null, null, null },
    change_gpout_divisor: [4]?u32 = .{ null, null, null, null },
    change_gpout_control: [4]?std.meta.fieldInfo(chip.reg_types.clk.GPOUT_Clock_Generator, .control).type = .{ null, null, null, null },
    enable_gpout: [4]?std.meta.fieldInfo(chip.reg_types.clk.GPOUT_Clock_Generator, .control).type = .{ null, null, null, null },

    disable_microtick: bool = false,
    disable_systick: bool = false,
    change_microtick_divisor: ?u9 = null,
    change_systick_source: ?std.meta.fieldInfo(@TypeOf(chip.SYSTICK.control_status).Type, .clock_source).type = null,
    change_systick_reload: ?u24 = null,
    enable_systick: bool = false,
    enable_microtick: bool = false,

    stop_xosc: bool = false,
    stop_rosc: bool = false,

    pub inline fn run(comptime self: Config_Change) void {
        if (self.resets_to_clear) |resets_to_clear| {
            resets.ensure_not_in_reset(resets_to_clear);
        }

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
            set_glitchless_ref_source(.rosc);
        }
        if (self.switch_ref_to_xosc) {
            set_glitchless_ref_source(.xosc);
        }
        if (self.change_ref_divisor_mid) |div| {
            chip.CLOCKS.ref.divisor.write(.{ .divisor = div });
        }
        if (self.switch_sys_to_ref) {
            set_glitchless_sys_source(.clk_ref);
        }
        if (self.change_sys_divisor_ref) |div| {
            chip.CLOCKS.sys.divisor.write(.{ .divisor = div });
        }
        self.sys_pll.init();
        self.usb_pll.init();
        self.sys_pll.wait_for_stable();
        self.usb_pll.wait_for_stable();
        if (self.switch_sys_aux) |aux_src| {
            chip.CLOCKS.sys.control.modify(.{ .aux_source = aux_src });
        }
        if (self.switch_sys_to_aux) {
            set_glitchless_sys_source(.aux);
        }
        if (self.change_sys_divisor_late) |div| {
            chip.CLOCKS.sys.divisor.write(div);
        }
        if (self.switch_ref_aux) |aux_src| {
            chip.CLOCKS.ref.control.modify(.{ .aux_source = aux_src });
        }
        if (self.switch_ref_to_aux) {
            set_glitchless_ref_source(.aux);
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
            chip.SYSTICK.current_value.write(.{ .value = 0 });
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

    fn set_glitchless_ref_source(comptime source: anytype) void {
        const ControlSource = std.meta.fieldInfo(@TypeOf(chip.CLOCKS.ref.control).Type, .source).type;
        const StatusSource = std.meta.fieldInfo(@TypeOf(chip.CLOCKS.ref.status).Type, .source).type;
        chip.CLOCKS.ref.control.modify(.{
            .source = std.enums.nameCast(ControlSource, source),
        });
        const expected_source = std.enums.nameCast(StatusSource, source);
        while (chip.CLOCKS.ref.status.read().source != expected_source) {}
    }

    fn set_glitchless_sys_source(comptime source: anytype) void {
        const ControlSource = std.meta.fieldInfo(@TypeOf(chip.CLOCKS.sys.control).Type, .source).type;
        const StatusSource = std.meta.fieldInfo(@TypeOf(chip.CLOCKS.sys.status).Type, .source).type;
        chip.CLOCKS.sys.control.modify(.{
            .source = std.enums.nameCast(ControlSource, source),
        });
        const expected_source = std.enums.nameCast(StatusSource, source);
        while (chip.CLOCKS.sys.status.read().source != expected_source) {}
    }
};

const ROSC_Divisor = std.meta.fieldInfo(@TypeOf(chip.ROSC.output_divisor).Type, .divisor).type;
fn encode_rosc_divisor(comptime divisor: comptime_int) ROSC_Divisor {
    return switch (divisor) {
        1...31 => @enumFromInt(0xAA0 + divisor),
        32 => .div32,
    };
}

pub fn init() void {
    const ch = comptime change: {
        var cc = Config_Change {};
        const config = get_config();

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
            cc.change_rosc_divisor_early = encode_rosc_divisor(config.rosc.params.divisor);
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
            if (cc.resets_to_clear) |*resets_to_clear| {
                resets_to_clear.pll_sys = true;
            } else {
                cc.resets_to_clear = .{ .pll_sys = true };
            }
            cc.sys_pll.disable_output_divisor = true;
            cc.sys_pll.change_input_divisor = config.sys_pll.vco.divisor;
            cc.sys_pll.change_multiplier = config.sys_pll.vco.multiplier;
            cc.sys_pll.should_wait_for_stable = true;
            cc.sys_pll.change_output_divisor = .{
                .divisor1 = config.sys_pll.output_divisor0,
                .divisor2 = config.sys_pll.output_divisor1,
            };
            cc.sys_pll.enable_output_divisor = true;
        }

        if (config.usb_pll.frequency_hz == 0) {
            cc.usb_pll.shutdown = true;
        } else {
            if (cc.resets_to_clear) |*resets_to_clear| {
                resets_to_clear.pll_usb = true;
            } else {
                cc.resets_to_clear = .{ .pll_usb = true };
            }
            cc.usb_pll.disable_output_divisor = true;
            cc.usb_pll.change_input_divisor = config.usb_pll.vco.divisor;
            cc.usb_pll.change_multiplier = config.usb_pll.vco.multiplier;
            cc.usb_pll.should_wait_for_stable = true;
            cc.usb_pll.change_output_divisor = .{
                .divisor1 = config.usb_pll.output_divisor0,
                .divisor2 = config.usb_pll.output_divisor1,
            };
            cc.usb_pll.enable_output_divisor = true;
        }

        for (0.., config.gpin) |n, gpin| {
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
                cc.change_ref_divisor_mid = config.ref.integer_divisor();
            },
            .xosc => {
                cc.switch_ref_to_xosc = true;
                cc.change_ref_divisor_mid = config.ref.integer_divisor();
            },
            .usb_pll => {
                if (config.xosc.frequency_hz > 0) {
                    cc.switch_ref_to_xosc = true;
                } else {
                    cc.switch_ref_to_rosc = true;
                }
                cc.switch_ref_aux = .pll_usb;
                cc.switch_ref_to_aux = true;
                cc.change_ref_divisor_late = config.ref.integer_divisor();
            },
            .gpin0 => {
                if (config.xosc.frequency_hz > 0) {
                    cc.switch_ref_to_xosc = true;
                } else {
                    cc.switch_ref_to_rosc = true;
                }
                cc.switch_ref_aux = .gpin0;
                cc.switch_ref_to_aux = true;
                cc.change_ref_divisor_late = config.ref.integer_divisor();
            },
            .gpin1 => {
                if (config.xosc.frequency_hz > 0) {
                    cc.switch_ref_to_xosc = true;
                } else {
                    cc.switch_ref_to_rosc = true;
                }
                cc.switch_ref_aux = .gpin1;
                cc.switch_ref_to_aux = true;
                cc.change_ref_divisor_late = config.ref.integer_divisor();
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
            cc.change_usb_divisor = config.usb.integer_divisor();
            cc.enable_usb = switch (config.usb.source) {
                .sys_pll => .pll_sys,
                .usb_pll => .pll_usb,
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
            cc.change_adc_divisor = config.adc.integer_divisor();
            cc.enable_adc = switch (config.adc.source) {
                .sys_pll => .pll_sys,
                .usb_pll => .pll_usb,
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
                .sys_pll => .pll_sys,
                .usb_pll => .pll_usb,
                .rosc => .rosc,
                .xosc => .xosc,
                .gpin0 => .gpin0,
                .gpin1 => .gpin1,
                else => unreachable,
            };
        }

        for (0.., config.gpout) |n, gpout| {
            if (gpout.generator.frequency_hz == 0) {
                cc.disable_gpout[n] = true;
                cc.setup_gpout_io[n] = .disabled;
            } else {
                var ctrl: std.meta.fieldInfo(chip.reg_types.clk.GPOUT_Clock_Generator, .control).type = .{
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

pub fn apply_config(comptime config: anytype, comptime previous_config: anytype) void {
    const parsed = comptime if (@TypeOf(config) == Parsed_Config) config else parse_config(config);
    const previous_parsed = comptime if (@TypeOf(previous_config) == Parsed_Config) previous_config else parse_config(previous_config);
    apply_parsed_config(parsed, previous_parsed);
}

fn apply_parsed_config(comptime parsed: Parsed_Config, comptime old: Parsed_Config) void {
    _ = old;
    _ = parsed;
    comptime change: {
        const cc = Config_Change {};

        // TODO

        break :change cc;
    }.run();
}

const timing = @import("timing.zig");
const resets = @import("resets.zig");
const util = @import("microbe").util;
const chip = @import("chip");
const root = @import("root");
const std = @import("std");
