// Generated by https://github.com/bcrist/microbe-regz
const microbe = @import("microbe");
const chip = @import("chip");
const Mmio = microbe.Mmio;

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

pub const INT = packed struct(u32) {
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
    INTR: Mmio(INT, .rw),
    INTE: Mmio(INT, .rw),
    INTF: Mmio(INT, .rw),
    INTS: Mmio(INT, .rw),
};
