// Generated by https://github.com/bcrist/microbe-regz
const Mmio = @import("microbe").Mmio;

pub const ADC = extern struct {
    CS: Mmio(packed struct(u32) {
        EN: u1 = 0,
        TS_EN: u1 = 0,
        START_ONCE: u1 = 0,
        START_MANY: u1 = 0,
        _reserved_4: u4 = 0,
        READY: u1 = 0,
        ERR: u1 = 0,
        ERR_STICKY: u1 = 0,
        _reserved_b: u1 = 0,
        AINSEL: u3 = 0,
        _reserved_f: u1 = 0,
        RROBIN: u5 = 0,
        _reserved_15: u11 = 0,
    }, .rw),
    RESULT: Mmio(packed struct(u32) {
        RESULT: u12 = 0,
        _reserved_c: u20 = 0,
    }, .rw),
    FCS: Mmio(packed struct(u32) {
        EN: u1 = 0,
        SHIFT: u1 = 0,
        ERR: u1 = 0,
        DREQ_EN: u1 = 0,
        _reserved_4: u4 = 0,
        EMPTY: u1 = 0,
        FULL: u1 = 0,
        UNDER: u1 = 0,
        OVER: u1 = 0,
        _reserved_c: u4 = 0,
        LEVEL: u4 = 0,
        _reserved_14: u4 = 0,
        THRESH: u4 = 0,
        _reserved_1c: u4 = 0,
    }, .rw),
    FIFO: Mmio(packed struct(u32) {
        VAL: u12 = 0,
        _reserved_c: u3 = 0,
        ERR: u1 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    DIV: Mmio(packed struct(u32) {
        FRAC: u8 = 0,
        INT: u16 = 0,
        _reserved_18: u8 = 0,
    }, .rw),
    INTR: Mmio(packed struct(u32) {
        FIFO: u1 = 0,
        _reserved_1: u31 = 0,
    }, .rw),
    INTE: Mmio(packed struct(u32) {
        FIFO: u1 = 0,
        _reserved_1: u31 = 0,
    }, .rw),
    INTF: Mmio(packed struct(u32) {
        FIFO: u1 = 0,
        _reserved_1: u31 = 0,
    }, .rw),
    INTS: Mmio(packed struct(u32) {
        FIFO: u1 = 0,
        _reserved_1: u31 = 0,
    }, .rw),
};
