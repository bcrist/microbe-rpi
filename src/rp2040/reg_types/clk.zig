// Generated by https://github.com/bcrist/microbe-regz
const Mmio = @import("microbe").Mmio;

pub const ENABLE = enum(u12) {
    DISABLE = 0xD1E,
    ENABLE = 0xFAB,
    _,
};

pub const COUNT = packed struct(u32) {
    COUNT: u8 = 0,
    _reserved_8: u24 = 0,
};

pub const XOSC = extern struct {
    CTRL: Mmio(packed struct(u32) {
        FREQ_RANGE: enum(u12) {
            @"1_15MHZ" = 0xAA0,
            RESERVED_1 = 0xAA1,
            RESERVED_2 = 0xAA2,
            RESERVED_3 = 0xAA3,
            _,
        } = @enumFromInt(0),
        ENABLE: ENABLE = @enumFromInt(0),
        _reserved_18: u8 = 0,
    }, .rw),
    STATUS: Mmio(packed struct(u32) {
        FREQ_RANGE: enum(u2) {
            @"1_15MHZ" = 0x0,
            RESERVED_1 = 0x1,
            RESERVED_2 = 0x2,
            RESERVED_3 = 0x3,
        } = .@"1_15MHZ",
        _reserved_2: u10 = 0,
        ENABLED: u1 = 0,
        _reserved_d: u11 = 0,
        BADWRITE: u1 = 0,
        _reserved_19: u6 = 0,
        STABLE: u1 = 0,
    }, .rw),
    DORMANT: Mmio(u32, .rw),
    STARTUP: Mmio(packed struct(u32) {
        DELAY: u14 = 0xC4,
        _reserved_e: u6 = 0,
        X4: u1 = 0,
        _reserved_15: u11 = 0,
    }, .rw),
    _reserved_10: [12]u8 = undefined,
    COUNT: Mmio(COUNT, .rw),
};

pub const PASSWD = enum(u16) {
    PASS = 0x9696,
    _,
};

pub const ROSC = extern struct {
    CTRL: Mmio(packed struct(u32) {
        FREQ_RANGE: enum(u12) {
            LOW = 0xFA4,
            MEDIUM = 0xFA5,
            TOOHIGH = 0xFA6,
            HIGH = 0xFA7,
            _,
        } = @enumFromInt(2720),
        ENABLE: ENABLE = @enumFromInt(0),
        _reserved_18: u8 = 0,
    }, .rw),
    FREQA: Mmio(packed struct(u32) {
        DS0: u3 = 0,
        _reserved_3: u1 = 0,
        DS1: u3 = 0,
        _reserved_7: u1 = 0,
        DS2: u3 = 0,
        _reserved_b: u1 = 0,
        DS3: u3 = 0,
        _reserved_f: u1 = 0,
        PASSWD: PASSWD = @enumFromInt(0),
    }, .rw),
    FREQB: Mmio(packed struct(u32) {
        DS4: u3 = 0,
        _reserved_3: u1 = 0,
        DS5: u3 = 0,
        _reserved_7: u1 = 0,
        DS6: u3 = 0,
        _reserved_b: u1 = 0,
        DS7: u3 = 0,
        _reserved_f: u1 = 0,
        PASSWD: PASSWD = @enumFromInt(0),
    }, .rw),
    DORMANT: Mmio(u32, .rw),
    DIV: Mmio(packed struct(u32) {
        DIV: enum(u12) {
            PASS = 0xAA0,
            _,
        } = @enumFromInt(0),
        _reserved_c: u20 = 0,
    }, .rw),
    PHASE: Mmio(packed struct(u32) {
        SHIFT: u2 = 0,
        FLIP: u1 = 0,
        ENABLE: u1 = 1,
        PASSWD: u8 = 0,
        _reserved_c: u20 = 0,
    }, .rw),
    STATUS: Mmio(packed struct(u32) {
        _reserved_0: u12 = 0,
        ENABLED: u1 = 0,
        _reserved_d: u3 = 0,
        DIV_RUNNING: u1 = 0,
        _reserved_11: u7 = 0,
        BADWRITE: u1 = 0,
        _reserved_19: u6 = 0,
        STABLE: u1 = 0,
    }, .rw),
    RANDOMBIT: Mmio(packed struct(u32) {
        RANDOMBIT: u1 = 1,
        _reserved_1: u31 = 0,
    }, .rw),
    COUNT: Mmio(COUNT, .rw),
};

pub const CLK_GPOUT = packed struct(u32) {
    _reserved_0: u5 = 0,
    AUXSRC: enum(u4) {
        clksrc_pll_sys = 0x0,
        clksrc_gpin0 = 0x1,
        clksrc_gpin1 = 0x2,
        clksrc_pll_usb = 0x3,
        rosc_clksrc = 0x4,
        xosc_clksrc = 0x5,
        clk_sys = 0x6,
        clk_usb = 0x7,
        clk_adc = 0x8,
        clk_rtc = 0x9,
        clk_ref = 0xA,
        _,
    } = .clksrc_pll_sys,
    _reserved_9: u1 = 0,
    KILL: u1 = 0,
    ENABLE: u1 = 0,
    DC50: u1 = 0,
    _reserved_d: u3 = 0,
    PHASE: u2 = 0,
    _reserved_12: u2 = 0,
    NUDGE: u1 = 0,
    _reserved_15: u11 = 0,
};

pub const CLK_ = packed struct(u32) {
    FRAC: u8 = 0,
    INT: u24 = 1,
};

pub const CLK_GPOUT_1 = packed struct(u32) {
    _reserved_0: u5 = 0,
    AUXSRC: enum(u4) {
        clksrc_pll_sys = 0x0,
        clksrc_gpin0 = 0x1,
        clksrc_gpin1 = 0x2,
        clksrc_pll_usb = 0x3,
        rosc_clksrc_ph = 0x4,
        xosc_clksrc = 0x5,
        clk_sys = 0x6,
        clk_usb = 0x7,
        clk_adc = 0x8,
        clk_rtc = 0x9,
        clk_ref = 0xA,
        _,
    } = .clksrc_pll_sys,
    _reserved_9: u1 = 0,
    KILL: u1 = 0,
    ENABLE: u1 = 0,
    DC50: u1 = 0,
    _reserved_d: u3 = 0,
    PHASE: u2 = 0,
    _reserved_12: u2 = 0,
    NUDGE: u1 = 0,
    _reserved_15: u11 = 0,
};

pub const CLK__1 = packed struct(u32) {
    _reserved_0: u8 = 0,
    INT: u2 = 1,
    _reserved_a: u22 = 0,
};

pub const CLK__2 = packed struct(u32) {
    _reserved_0: u5 = 0,
    AUXSRC: enum(u3) {
        clksrc_pll_usb = 0x0,
        clksrc_pll_sys = 0x1,
        rosc_clksrc_ph = 0x2,
        xosc_clksrc = 0x3,
        clksrc_gpin0 = 0x4,
        clksrc_gpin1 = 0x5,
        _,
    } = .clksrc_pll_usb,
    _reserved_8: u2 = 0,
    KILL: u1 = 0,
    ENABLE: u1 = 0,
    _reserved_c: u4 = 0,
    PHASE: u2 = 0,
    _reserved_12: u2 = 0,
    NUDGE: u1 = 0,
    _reserved_15: u11 = 0,
};

pub const SLEEP_EN0 = packed struct(u32) {
    clk_sys_clocks: u1 = 1,
    clk_adc_adc: u1 = 1,
    clk_sys_adc: u1 = 1,
    clk_sys_busctrl: u1 = 1,
    clk_sys_busfabric: u1 = 1,
    clk_sys_dma: u1 = 1,
    clk_sys_i2c0: u1 = 1,
    clk_sys_i2c1: u1 = 1,
    clk_sys_io: u1 = 1,
    clk_sys_jtag: u1 = 1,
    clk_sys_vreg_and_chip_reset: u1 = 1,
    clk_sys_pads: u1 = 1,
    clk_sys_pio0: u1 = 1,
    clk_sys_pio1: u1 = 1,
    clk_sys_pll_sys: u1 = 1,
    clk_sys_pll_usb: u1 = 1,
    clk_sys_psm: u1 = 1,
    clk_sys_pwm: u1 = 1,
    clk_sys_resets: u1 = 1,
    clk_sys_rom: u1 = 1,
    clk_sys_rosc: u1 = 1,
    clk_rtc_rtc: u1 = 1,
    clk_sys_rtc: u1 = 1,
    clk_sys_sio: u1 = 1,
    clk_peri_spi0: u1 = 1,
    clk_sys_spi0: u1 = 1,
    clk_peri_spi1: u1 = 1,
    clk_sys_spi1: u1 = 1,
    clk_sys_sram0: u1 = 1,
    clk_sys_sram1: u1 = 1,
    clk_sys_sram2: u1 = 1,
    clk_sys_sram3: u1 = 1,
};

pub const SLEEP_EN1 = packed struct(u32) {
    clk_sys_sram4: u1 = 1,
    clk_sys_sram5: u1 = 1,
    clk_sys_syscfg: u1 = 1,
    clk_sys_sysinfo: u1 = 1,
    clk_sys_tbman: u1 = 1,
    clk_sys_timer: u1 = 1,
    clk_peri_uart0: u1 = 1,
    clk_sys_uart0: u1 = 1,
    clk_peri_uart1: u1 = 1,
    clk_sys_uart1: u1 = 1,
    clk_sys_usbctrl: u1 = 1,
    clk_usb_usbctrl: u1 = 1,
    clk_sys_watchdog: u1 = 1,
    clk_sys_xip: u1 = 1,
    clk_sys_xosc: u1 = 1,
    _reserved_f: u17 = 0,
};

pub const INT = packed struct(u32) {
    CLK_SYS_RESUS: u1 = 0,
    _reserved_1: u31 = 0,
};

pub const CLOCKS = extern struct {
    CLK_GPOUT0_CTRL: Mmio(CLK_GPOUT, .rw),
    CLK_GPOUT0_DIV: Mmio(CLK_, .rw),
    CLK_GPOUT0_SELECTED: Mmio(u32, .r),
    CLK_GPOUT1_CTRL: Mmio(CLK_GPOUT, .rw),
    CLK_GPOUT1_DIV: Mmio(CLK_, .rw),
    CLK_GPOUT1_SELECTED: Mmio(u32, .r),
    CLK_GPOUT2_CTRL: Mmio(CLK_GPOUT_1, .rw),
    CLK_GPOUT2_DIV: Mmio(CLK_, .rw),
    CLK_GPOUT2_SELECTED: Mmio(u32, .r),
    CLK_GPOUT3_CTRL: Mmio(CLK_GPOUT_1, .rw),
    CLK_GPOUT3_DIV: Mmio(CLK_, .rw),
    CLK_GPOUT3_SELECTED: Mmio(u32, .r),
    CLK_REF_CTRL: Mmio(packed struct(u32) {
        SRC: enum(u2) {
            rosc_clksrc_ph = 0x0,
            clksrc_clk_ref_aux = 0x1,
            xosc_clksrc = 0x2,
            _,
        } = .rosc_clksrc_ph,
        _reserved_2: u3 = 0,
        AUXSRC: enum(u2) {
            clksrc_pll_usb = 0x0,
            clksrc_gpin0 = 0x1,
            clksrc_gpin1 = 0x2,
            _,
        } = .clksrc_pll_usb,
        _reserved_7: u25 = 0,
    }, .rw),
    CLK_REF_DIV: Mmio(CLK__1, .rw),
    CLK_REF_SELECTED: Mmio(u32, .r),
    CLK_SYS_CTRL: Mmio(packed struct(u32) {
        SRC: enum(u1) {
            clk_ref = 0x0,
            clksrc_clk_sys_aux = 0x1,
        } = .clk_ref,
        _reserved_1: u4 = 0,
        AUXSRC: enum(u3) {
            clksrc_pll_sys = 0x0,
            clksrc_pll_usb = 0x1,
            rosc_clksrc = 0x2,
            xosc_clksrc = 0x3,
            clksrc_gpin0 = 0x4,
            clksrc_gpin1 = 0x5,
            _,
        } = .clksrc_pll_sys,
        _reserved_8: u24 = 0,
    }, .rw),
    CLK_SYS_DIV: Mmio(CLK_, .rw),
    CLK_SYS_SELECTED: Mmio(u32, .r),
    CLK_PERI_CTRL: Mmio(packed struct(u32) {
        _reserved_0: u5 = 0,
        AUXSRC: enum(u3) {
            clk_sys = 0x0,
            clksrc_pll_sys = 0x1,
            clksrc_pll_usb = 0x2,
            rosc_clksrc_ph = 0x3,
            xosc_clksrc = 0x4,
            clksrc_gpin0 = 0x5,
            clksrc_gpin1 = 0x6,
            _,
        } = .clk_sys,
        _reserved_8: u2 = 0,
        KILL: u1 = 0,
        ENABLE: u1 = 0,
        _reserved_c: u20 = 0,
    }, .rw),
    _reserved_4c: [4]u8 = undefined,
    CLK_PERI_SELECTED: Mmio(u32, .r),
    CLK_USB_CTRL: Mmio(CLK__2, .rw),
    CLK_USB_DIV: Mmio(CLK__1, .rw),
    CLK_USB_SELECTED: Mmio(u32, .r),
    CLK_ADC_CTRL: Mmio(CLK__2, .rw),
    CLK_ADC_DIV: Mmio(CLK__1, .rw),
    CLK_ADC_SELECTED: Mmio(u32, .r),
    CLK_RTC_CTRL: Mmio(CLK__2, .rw),
    CLK_RTC_DIV: Mmio(CLK_, .rw),
    CLK_RTC_SELECTED: Mmio(u32, .r),
    CLK_SYS_RESUS_CTRL: Mmio(packed struct(u32) {
        TIMEOUT: u8 = 0xFF,
        ENABLE: u1 = 0,
        _reserved_9: u3 = 0,
        FRCE: u1 = 0,
        _reserved_d: u3 = 0,
        CLEAR: u1 = 0,
        _reserved_11: u15 = 0,
    }, .rw),
    CLK_SYS_RESUS_STATUS: Mmio(packed struct(u32) {
        RESUSSED: u1 = 0,
        _reserved_1: u31 = 0,
    }, .rw),
    FC0_REF_KHZ: Mmio(packed struct(u32) {
        FC0_REF_KHZ: u20 = 0,
        _reserved_14: u12 = 0,
    }, .rw),
    FC0_MIN_KHZ: Mmio(packed struct(u32) {
        FC0_MIN_KHZ: u25 = 0,
        _reserved_19: u7 = 0,
    }, .rw),
    FC0_MAX_KHZ: Mmio(packed struct(u32) {
        FC0_MAX_KHZ: u25 = 0x1FFFFFF,
        _reserved_19: u7 = 0,
    }, .rw),
    FC0_DELAY: Mmio(packed struct(u32) {
        FC0_DELAY: u3 = 1,
        _reserved_3: u29 = 0,
    }, .rw),
    FC0_INTERVAL: Mmio(packed struct(u32) {
        FC0_INTERVAL: u4 = 8,
        _reserved_4: u28 = 0,
    }, .rw),
    FC0_SRC: Mmio(packed struct(u32) {
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
    FC0_STATUS: Mmio(packed struct(u32) {
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
    FC0_RESULT: Mmio(packed struct(u32) {
        FRAC: u5 = 0,
        KHZ: u25 = 0,
        _reserved_1e: u2 = 0,
    }, .rw),
    WAKE_EN0: Mmio(SLEEP_EN0, .rw),
    WAKE_EN1: Mmio(SLEEP_EN1, .rw),
    SLEEP_EN0: Mmio(SLEEP_EN0, .rw),
    SLEEP_EN1: Mmio(SLEEP_EN1, .rw),
    ENABLED0: Mmio(packed struct(u32) {
        clk_sys_clocks: u1 = 0,
        clk_adc_adc: u1 = 0,
        clk_sys_adc: u1 = 0,
        clk_sys_busctrl: u1 = 0,
        clk_sys_busfabric: u1 = 0,
        clk_sys_dma: u1 = 0,
        clk_sys_i2c0: u1 = 0,
        clk_sys_i2c1: u1 = 0,
        clk_sys_io: u1 = 0,
        clk_sys_jtag: u1 = 0,
        clk_sys_vreg_and_chip_reset: u1 = 0,
        clk_sys_pads: u1 = 0,
        clk_sys_pio0: u1 = 0,
        clk_sys_pio1: u1 = 0,
        clk_sys_pll_sys: u1 = 0,
        clk_sys_pll_usb: u1 = 0,
        clk_sys_psm: u1 = 0,
        clk_sys_pwm: u1 = 0,
        clk_sys_resets: u1 = 0,
        clk_sys_rom: u1 = 0,
        clk_sys_rosc: u1 = 0,
        clk_rtc_rtc: u1 = 0,
        clk_sys_rtc: u1 = 0,
        clk_sys_sio: u1 = 0,
        clk_peri_spi0: u1 = 0,
        clk_sys_spi0: u1 = 0,
        clk_peri_spi1: u1 = 0,
        clk_sys_spi1: u1 = 0,
        clk_sys_sram0: u1 = 0,
        clk_sys_sram1: u1 = 0,
        clk_sys_sram2: u1 = 0,
        clk_sys_sram3: u1 = 0,
    }, .rw),
    ENABLED1: Mmio(packed struct(u32) {
        clk_sys_sram4: u1 = 0,
        clk_sys_sram5: u1 = 0,
        clk_sys_syscfg: u1 = 0,
        clk_sys_sysinfo: u1 = 0,
        clk_sys_tbman: u1 = 0,
        clk_sys_timer: u1 = 0,
        clk_peri_uart0: u1 = 0,
        clk_sys_uart0: u1 = 0,
        clk_peri_uart1: u1 = 0,
        clk_sys_uart1: u1 = 0,
        clk_sys_usbctrl: u1 = 0,
        clk_usb_usbctrl: u1 = 0,
        clk_sys_watchdog: u1 = 0,
        clk_sys_xip: u1 = 0,
        clk_sys_xosc: u1 = 0,
        _reserved_f: u17 = 0,
    }, .rw),
    INTR: Mmio(INT, .rw),
    INTE: Mmio(INT, .rw),
    INTF: Mmio(INT, .rw),
    INTS: Mmio(INT, .rw),
};

pub const RTC_1 = packed struct(u32) {
    DAY: u5 = 0,
    _reserved_5: u3 = 0,
    MONTH: u4 = 0,
    YEAR: u12 = 0,
    _reserved_18: u8 = 0,
};

pub const RTC_0 = packed struct(u32) {
    SEC: u6 = 0,
    _reserved_6: u2 = 0,
    MIN: u6 = 0,
    _reserved_e: u2 = 0,
    HOUR: u5 = 0,
    _reserved_15: u3 = 0,
    DOTW: u3 = 0,
    _reserved_1b: u5 = 0,
};

pub const INT_1 = packed struct(u32) {
    RTC: u1 = 0,
    _reserved_1: u31 = 0,
};

pub const RTC = extern struct {
    CLKDIV_M1: Mmio(packed struct(u32) {
        CLKDIV_M1: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    SETUP_0: Mmio(RTC_1, .rw),
    SETUP_1: Mmio(RTC_0, .rw),
    CTRL: Mmio(packed struct(u32) {
        RTC_ENABLE: u1 = 0,
        RTC_ACTIVE: u1 = 0,
        _reserved_2: u2 = 0,
        LOAD: u1 = 0,
        _reserved_5: u3 = 0,
        FORCE_NOTLEAPYEAR: u1 = 0,
        _reserved_9: u23 = 0,
    }, .rw),
    IRQ_SETUP_0: Mmio(packed struct(u32) {
        DAY: u5 = 0,
        _reserved_5: u3 = 0,
        MONTH: u4 = 0,
        YEAR: u12 = 0,
        DAY_ENA: u1 = 0,
        MONTH_ENA: u1 = 0,
        YEAR_ENA: u1 = 0,
        _reserved_1b: u1 = 0,
        MATCH_ENA: u1 = 0,
        MATCH_ACTIVE: u1 = 0,
        _reserved_1e: u2 = 0,
    }, .rw),
    IRQ_SETUP_1: Mmio(packed struct(u32) {
        SEC: u6 = 0,
        _reserved_6: u2 = 0,
        MIN: u6 = 0,
        _reserved_e: u2 = 0,
        HOUR: u5 = 0,
        _reserved_15: u3 = 0,
        DOTW: u3 = 0,
        _reserved_1b: u1 = 0,
        SEC_ENA: u1 = 0,
        MIN_ENA: u1 = 0,
        HOUR_ENA: u1 = 0,
        DOTW_ENA: u1 = 0,
    }, .rw),
    RTC_1: Mmio(RTC_1, .rw),
    RTC_0: Mmio(RTC_0, .rw),
    INTR: Mmio(INT_1, .rw),
    INTE: Mmio(INT_1, .rw),
    INTF: Mmio(INT_1, .rw),
    INTS: Mmio(INT_1, .rw),
};

pub const INT_2 = packed struct(u32) {
    ALARM_0: u1 = 0,
    ALARM_1: u1 = 0,
    ALARM_2: u1 = 0,
    ALARM_3: u1 = 0,
    _reserved_4: u28 = 0,
};

pub const TIMER = extern struct {
    TIMEHW: Mmio(u32, .w),
    TIMELW: Mmio(u32, .w),
    TIMEHR: Mmio(u32, .r),
    TIMELR: Mmio(u32, .r),
    ALARM0: Mmio(u32, .rw),
    ALARM1: Mmio(u32, .rw),
    ALARM2: Mmio(u32, .rw),
    ALARM3: Mmio(u32, .rw),
    ARMED: Mmio(packed struct(u32) {
        ARMED: u4 = 0,
        _reserved_4: u28 = 0,
    }, .rw),
    TIMERAWH: Mmio(u32, .r),
    TIMERAWL: Mmio(u32, .r),
    DBGPAUSE: Mmio(packed struct(u32) {
        _reserved_0: u1 = 0,
        DBG0: u1 = 1,
        DBG1: u1 = 1,
        _reserved_3: u29 = 0,
    }, .rw),
    PAUSE: Mmio(packed struct(u32) {
        PAUSE: u1 = 0,
        _reserved_1: u31 = 0,
    }, .rw),
    INTR: Mmio(INT_2, .rw),
    INTE: Mmio(INT_2, .rw),
    INTF: Mmio(INT_2, .rw),
    INTS: Mmio(INT_2, .rw),
};

pub const PLL = extern struct {
    CS: Mmio(packed struct(u32) {
        REFDIV: u6 = 1,
        _reserved_6: u2 = 0,
        BYPASS: u1 = 0,
        _reserved_9: u22 = 0,
        LOCK: u1 = 0,
    }, .rw),
    PWR: Mmio(packed struct(u32) {
        PD: u1 = 1,
        _reserved_1: u1 = 0,
        DSMPD: u1 = 1,
        POSTDIVPD: u1 = 1,
        _reserved_4: u1 = 0,
        VCOPD: u1 = 1,
        _reserved_6: u26 = 0,
    }, .rw),
    FBDIV_INT: Mmio(packed struct(u32) {
        FBDIV_INT: u12 = 0,
        _reserved_c: u20 = 0,
    }, .rw),
    PRIM: Mmio(packed struct(u32) {
        _reserved_0: u12 = 0,
        POSTDIV2: u3 = 7,
        _reserved_f: u1 = 0,
        POSTDIV1: u3 = 7,
        _reserved_13: u13 = 0,
    }, .rw),
};
