// Generated by https://github.com/bcrist/microbe-regz
const Mmio = @import("microbe").Mmio;

pub const INT = packed struct(u32) {
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
    INTR: Mmio(INT, .rw),
    INTE: Mmio(INT, .rw),
    INTF: Mmio(INT, .rw),
    INTS: Mmio(INT, .rw),
};
