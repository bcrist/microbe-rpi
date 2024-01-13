// Generated by https://github.com/bcrist/microbe-regz
const microbe = @import("microbe");
const chip = @import("chip");
const MMIO = microbe.MMIO;

pub const XOSC = extern struct {
    control: MMIO(packed struct(u32) {
        range: u12 = 0xAA0,
        enabled: enum(u12) {
            disabled = 0xD1E,
            enabled = 0xFAB,
            _,
        } = .disabled,
        _reserved_18: u8 = 0,
    }, .rw),
    status: MMIO(packed struct(u32) {
        _reserved_0: u12 = 0,
        enabled: bool = false,
        _reserved_d: u18 = 0,
        stable: bool = false,
    }, .r),
    pause: MMIO(enum(u32) {
        shutdown_until_interrupt = 0x636F6D61,
        _,
    }, .rw),
    startup_delay: MMIO(packed struct(u32) {
        cycles_div256: u14 = 0xC4,
        _reserved_e: u18 = 0,
    }, .rw),
};

pub const ROSC_Stage_Drive_Strength = enum(u3) {
    @"1x" = 0,
    @"2x" = 1,
    @"3x" = 3,
    @"4x" = 7,
    _,
};

pub const ROSC = extern struct {
    control: MMIO(packed struct(u32) {
        range: enum(u12) {
            /// 8 stages
            low = 0xFA4,

            /// 6 stages
            medium = 0xFA5,

            /// 4 stages
            high = 0xFA7,

            _,
        } = .low,
        enabled: enum(u12) {
            disabled = 0xD1E,
            enabled = 0xFAB,
            _,
        } = .disabled,
        _reserved_18: u8 = 0,
    }, .rw),
    drive0: MMIO(packed struct(u32) {
        stage0: ROSC_Stage_Drive_Strength = .@"1x",
        _reserved_3: u1 = 0,
        stage1: ROSC_Stage_Drive_Strength = .@"1x",
        _reserved_7: u1 = 0,
        stage2: ROSC_Stage_Drive_Strength = .@"1x",
        _reserved_b: u1 = 0,
        stage3: ROSC_Stage_Drive_Strength = .@"1x",
        _reserved_f: u1 = 0,
        write_enable_key: u16 = 0x9696,
    }, .rw),
    drive1: MMIO(packed struct(u32) {
        stage4: ROSC_Stage_Drive_Strength = .@"1x",
        _reserved_3: u1 = 0,
        stage5: ROSC_Stage_Drive_Strength = .@"1x",
        _reserved_7: u1 = 0,
        stage6: ROSC_Stage_Drive_Strength = .@"1x",
        _reserved_b: u1 = 0,
        stage7: ROSC_Stage_Drive_Strength = .@"1x",
        _reserved_f: u1 = 0,
        write_enable_key: u16 = 0x9696,
    }, .rw),
    pause: MMIO(enum(u32) {
        shutdown_until_interrupt = 0x636F6D61,
        _,
    }, .rw),
    output_divisor: MMIO(packed struct(u32) {
        divisor: enum(u12) {
            div32 = 0xAA0,
            div1 = 0xAA1,
            div2 = 0xAA2,
            div3 = 0xAA3,
            div4 = 0xAA4,
            div5 = 0xAA5,
            div6 = 0xAA6,
            div7 = 0xAA7,
            div8 = 0xAA8,
            div9 = 0xAA9,
            div10 = 0xAAA,
            div11 = 0xAAB,
            div12 = 0xAAC,
            div13 = 0xAAD,
            div14 = 0xAAE,
            div15 = 0xAAF,
            div16 = 0xAB0,
            div17 = 0xAB1,
            div18 = 0xAB2,
            div19 = 0xAB3,
            div20 = 0xAB4,
            div21 = 0xAB5,
            div22 = 0xAB6,
            div23 = 0xAB7,
            div24 = 0xAB8,
            div25 = 0xAB9,
            div26 = 0xABA,
            div27 = 0xABB,
            div28 = 0xABC,
            div29 = 0xABD,
            div30 = 0xABE,
            div31 = 0xABF,
            _,
        } = .div16,
        _reserved_c: u20 = 0,
    }, .rw),
    _reserved_14: [4]u8 = undefined,
    status: MMIO(packed struct(u32) {
        _reserved_0: u12 = 0,
        enabled: bool = false,
        _reserved_d: u3 = 0,
        divider_running: bool = false,
        _reserved_11: u14 = 0,
        stable: bool = false,
    }, .r),
    random: MMIO(packed struct(u32) {
        bit: u1 = 1,
        _reserved_1: u31 = 0,
    }, .rw),
};

pub const PLL = extern struct {
    control_status: MMIO(packed struct(u32) {
        /// 1 - 31
        input_divisor: u6 = 1,

        _reserved_6: u2 = 0,
        bypass: bool = false,
        _reserved_9: u22 = 0,
        locked: bool = false,
    }, .rw),
    power: MMIO(enum(u32) {
        run = 0x4,
        vco_startup = 0xC,
        bypass = 0x2C,
        shutdown = 0x2D,
        _,
    }, .rw),
    multiplier: MMIO(packed struct(u32) {
        /// 16 - 320
        factor: u12 = 0,

        _reserved_c: u20 = 0,
    }, .rw),
    output: MMIO(packed struct(u32) {
        _reserved_0: u12 = 0,

        /// 1-7; should be <= POSTDIV1
        divisor2: u3 = 7,

        _reserved_f: u1 = 0,

        /// 1-7
        divisor1: u3 = 7,

        _reserved_13: u13 = 0,
    }, .rw),
};

pub const Div123 = enum(u2) {
    none = 1,
    div2 = 2,
    div3 = 3,
    _,
};

pub const GPOUT_Clock_Generator = extern struct {
    control: MMIO(packed struct(u32) {
        _reserved_0: u5 = 0,
        source: enum(u4) {
            pll_sys = 0,
            gpin0 = 1,
            gpin1 = 2,
            pll_usb = 3,
            rosc = 4,
            xosc = 5,
            clk_sys = 6,
            clk_usb = 7,
            clk_adc = 8,
            clk_rtc = 9,
            clk_ref = 10,
            _,
        } = .pll_sys,
        _reserved_9: u1 = 0,
        kill: bool = false,
        enabled: bool = false,
        duty_cycle_correction: bool = false,
        _reserved_d: u3 = 0,
        initial_phase_delay: u2 = 0,
        _reserved_12: u2 = 0,
        nudge_phase: bool = false,
        _reserved_15: u11 = 0,
    }, .rw),

    /// 8 fractional bits
    divisor: MMIO(u32, .rw),

    _reserved_8: [4]u8 = undefined,
};

pub const Ref_Clock_Generator = extern struct {
    control: MMIO(packed struct(u32) {
        source: enum(u2) {
            rosc = 0,
            aux = 1,
            xosc = 2,
            _,
        } = .rosc,
        _reserved_2: u3 = 0,
        aux_source: enum(u2) {
            pll_usb = 0,
            gpin0 = 1,
            gpin1 = 2,
            _,
        } = .pll_usb,
        _reserved_7: u25 = 0,
    }, .rw),
    divisor: MMIO(packed struct(u32) {
        _reserved_0: u8 = 0,
        divisor: Div123 = .none,
        _reserved_a: u22 = 0,
    }, .rw),
    status: MMIO(packed struct(u32) {
        source: enum(u3) {
            rosc = 1,
            aux = 2,
            xosc = 4,
            _,
        } = .rosc,
        _reserved_3: u29 = 0,
    }, .r),
};

pub const Sys_Clock_Generator = extern struct {
    control: MMIO(packed struct(u32) {
        source: enum(u1) {
            clk_ref = 0,
            aux = 1,
        } = .clk_ref,
        _reserved_1: u4 = 0,
        aux_source: enum(u3) {
            pll_sys = 0,
            pll_usb = 1,
            rosc = 2,
            xosc = 3,
            gpin0 = 4,
            gpin1 = 5,
            _,
        } = .pll_sys,
        _reserved_8: u24 = 0,
    }, .rw),

    /// 8 fractional bits
    divisor: MMIO(u32, .rw),

    status: MMIO(packed struct(u32) {
        source: enum(u2) {
            clk_ref = 1,
            aux = 2,
            _,
        } = .clk_ref,
        _reserved_2: u30 = 0,
    }, .r),
};

pub const Peri_Clock_Generator = extern struct {
    control: MMIO(packed struct(u32) {
        _reserved_0: u5 = 0,
        source: enum(u3) {
            clk_sys = 0,
            pll_sys = 1,
            pll_usb = 2,
            rosc = 3,
            xosc = 4,
            gpin0 = 5,
            gpin1 = 6,
            _,
        } = .clk_sys,
        _reserved_8: u2 = 0,
        kill: bool = false,
        enabled: bool = false,
        _reserved_c: u20 = 0,
    }, .rw),
    _reserved_4: [8]u8 = undefined,
};

pub const USB_ADC_Clock_Generator = extern struct {
    control: MMIO(packed struct(u32) {
        _reserved_0: u5 = 0,
        source: enum(u3) {
            pll_usb = 0,
            pll_sys = 1,
            rosc = 2,
            xosc = 3,
            gpin0 = 4,
            gpin1 = 5,
            _,
        } = .pll_usb,
        _reserved_8: u2 = 0,
        kill: bool = false,
        enabled: bool = false,
        _reserved_c: u4 = 0,
        initial_phase_delay: u2 = 0,
        _reserved_12: u2 = 0,
        nudge_phase: bool = false,
        _reserved_15: u11 = 0,
    }, .rw),
    divisor: MMIO(packed struct(u32) {
        _reserved_0: u8 = 0,
        divisor: Div123 = .none,
        _reserved_a: u22 = 0,
    }, .rw),
    _reserved_8: [4]u8 = undefined,
};

pub const RTC_Clock_Generator = extern struct {
    control: MMIO(packed struct(u32) {
        _reserved_0: u5 = 0,
        source: enum(u3) {
            pll_usb = 0,
            pll_sys = 1,
            rosc = 2,
            xosc = 3,
            gpin0 = 4,
            gpin1 = 5,
            _,
        } = .pll_usb,
        _reserved_8: u2 = 0,
        kill: bool = false,
        enabled: bool = false,
        _reserved_c: u4 = 0,
        initial_phase_delay: u2 = 0,
        _reserved_12: u2 = 0,
        nudge_phase: bool = false,
        _reserved_15: u11 = 0,
    }, .rw),

    /// 8 fractional bits
    divisor: MMIO(u32, .rw),

    _reserved_8: [4]u8 = undefined,
};

pub const Enable_Bitmap_0 = packed struct(u32) {
    clk_sys_clocks: bool = true,
    clk_adc_adc: bool = true,
    clk_sys_adc: bool = true,
    clk_sys_busctrl: bool = true,
    clk_sys_busfabric: bool = true,
    clk_sys_dma: bool = true,
    clk_sys_i2c0: bool = true,
    clk_sys_i2c1: bool = true,
    clk_sys_io: bool = true,
    clk_sys_jtag: bool = true,
    clk_sys_vreg_and_chip_reset: bool = true,
    clk_sys_pads: bool = true,
    clk_sys_pio0: bool = true,
    clk_sys_pio1: bool = true,
    clk_sys_pll_sys: bool = true,
    clk_sys_pll_usb: bool = true,
    clk_sys_psm: bool = true,
    clk_sys_pwm: bool = true,
    clk_sys_resets: bool = true,
    clk_sys_rom: bool = true,
    clk_sys_rosc: bool = true,
    clk_rtc_rtc: bool = true,
    clk_sys_rtc: bool = true,
    clk_sys_sio: bool = true,
    clk_peri_spi0: bool = true,
    clk_sys_spi0: bool = true,
    clk_peri_spi1: bool = true,
    clk_sys_spi1: bool = true,
    clk_sys_sram0: bool = true,
    clk_sys_sram1: bool = true,
    clk_sys_sram2: bool = true,
    clk_sys_sram3: bool = true,
};

pub const Enable_Bitmap_1 = packed struct(u32) {
    clk_sys_sram4: bool = true,
    clk_sys_sram5: bool = true,
    clk_sys_syscfg: bool = true,
    clk_sys_sysinfo: bool = true,
    clk_sys_tbman: bool = true,
    clk_sys_timer: bool = true,
    clk_peri_uart0: bool = true,
    clk_sys_uart0: bool = true,
    clk_peri_uart1: bool = true,
    clk_sys_uart1: bool = true,
    clk_sys_usbctrl: bool = true,
    clk_usb_usbctrl: bool = true,
    clk_sys_watchdog: bool = true,
    clk_sys_xip: bool = true,
    clk_sys_xosc: bool = true,
    _reserved_f: u17 = 0,
};

pub const Interrupt_Bitmap = packed struct(u32) {
    resus: bool = false,
    _reserved_1: u31 = 0,
};

pub const CLOCKS = extern struct {
    gpout: [4]GPOUT_Clock_Generator,
    ref: Ref_Clock_Generator,
    sys: Sys_Clock_Generator,
    peri: Peri_Clock_Generator,
    usb: USB_ADC_Clock_Generator,
    adc: USB_ADC_Clock_Generator,
    rtc: RTC_Clock_Generator,
    resus: extern struct {
        control: MMIO(packed struct(u32) {
            timeout: u8 = 0xFF,
            enabled: bool = false,
            _reserved_9: u3 = 0,
            force: bool = false,
            _reserved_d: u3 = 0,
            clear: bool = false,
            _reserved_11: u15 = 0,
        }, .rw),
        status: MMIO(packed struct(u32) {
            resuscitated: bool = false,
            _reserved_1: u31 = 0,
        }, .rw),
    },
    _reserved_80: [32]u8 = undefined,
    wake_enable: extern struct {
        _0: MMIO(Enable_Bitmap_0, .rw),
        _1: MMIO(Enable_Bitmap_1, .rw),
    },
    sleep_enable: extern struct {
        _0: MMIO(Enable_Bitmap_0, .rw),
        _1: MMIO(Enable_Bitmap_1, .rw),
    },
    enabled_status: extern struct {
        _0: MMIO(Enable_Bitmap_0, .r),
        _1: MMIO(Enable_Bitmap_1, .r),
    },
    interrupt_status: MMIO(Interrupt_Bitmap, .r),
    irq: extern struct {
        enable: MMIO(Interrupt_Bitmap, .rw),
        force: MMIO(Interrupt_Bitmap, .rw),
        status: MMIO(Interrupt_Bitmap, .r),
    },
};

pub const FREQ_COUNTER = extern struct {
    ref_freq: MMIO(packed struct(u32) {
        FC0_REF_KHZ: u20 = 0,
        _reserved_14: u12 = 0,
    }, .rw),
    min_freq: MMIO(packed struct(u32) {
        FC0_MIN_KHZ: u25 = 0,
        _reserved_19: u7 = 0,
    }, .rw),
    max_freq: MMIO(packed struct(u32) {
        FC0_MAX_KHZ: u25 = 0x1FFFFFF,
        _reserved_19: u7 = 0,
    }, .rw),
    delay: MMIO(packed struct(u32) {
        FC0_DELAY: u3 = 1,
        _reserved_3: u29 = 0,
    }, .rw),
    interval: MMIO(packed struct(u32) {
        FC0_INTERVAL: u4 = 8,
        _reserved_4: u28 = 0,
    }, .rw),
    source: MMIO(packed struct(u32) {
        FC0_SRC: enum(u8) {
            NULL = 0x0,
            pll_sys_clksrc_primary = 0x1,
            pll_usb_clksrc_primary = 0x2,
            rosc_clksrc = 0x3,
            rosc_clksrc_ph = 0x4,
            xosc_clksrc = 0x5,
            clksrc_gpin0 = 0x6,
            clksrc_gpin1 = 0x7,
            clk_ref = 0x8,
            clk_sys = 0x9,
            clk_peri = 0xA,
            clk_usb = 0xB,
            clk_adc = 0xC,
            clk_rtc = 0xD,
            _,
        } = .NULL,
        _reserved_8: u24 = 0,
    }, .rw),
    status: MMIO(packed struct(u32) {
        PASS: u1 = 0,
        _reserved_1: u3 = 0,
        DONE: u1 = 0,
        _reserved_5: u3 = 0,
        RUNNING: u1 = 0,
        _reserved_9: u3 = 0,
        WAITING: u1 = 0,
        _reserved_d: u3 = 0,
        FAIL: u1 = 0,
        _reserved_11: u3 = 0,
        SLOW: u1 = 0,
        _reserved_15: u3 = 0,
        FAST: u1 = 0,
        _reserved_19: u3 = 0,
        DIED: u1 = 0,
        _reserved_1d: u3 = 0,
    }, .rw),
    result: MMIO(packed struct(u32) {
        FRAC: u5 = 0,
        KHZ: u25 = 0,
        _reserved_1e: u2 = 0,
    }, .rw),
};
