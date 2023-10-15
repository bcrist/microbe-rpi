// Generated by https://github.com/bcrist/microbe-regz
const microbe = @import("microbe");
const chip = @import("chip");
const Mmio = microbe.Mmio;

pub const SM3_CLKDIV = packed struct(u32) {
    _reserved_0: u8 = 0,
    FRAC: u8 = 0,
    INT: u16 = 1,
};

pub const SM3_EXECCTRL = packed struct(u32) {
    STATUS_N: u4 = 0,
    STATUS_SEL: enum(u1) {
        TXLEVEL = 0,
        RXLEVEL = 1,
    } = .TXLEVEL,
    _reserved_5: u2 = 0,
    WRAP_BOTTOM: u5 = 0,
    WRAP_TOP: u5 = 0x1F,
    OUT_STICKY: u1 = 0,
    INLINE_OUT_EN: u1 = 0,
    OUT_EN_SEL: u5 = 0,
    JMP_PIN: u5 = 0,
    SIDE_PINDIR: u1 = 0,
    SIDE_EN: u1 = 0,
    EXEC_STALLED: u1 = 0,
};

pub const SM3_SHIFTCTRL = packed struct(u32) {
    _reserved_0: u16 = 0,
    AUTOPUSH: u1 = 0,
    AUTOPULL: u1 = 0,
    IN_SHIFTDIR: u1 = 1,
    OUT_SHIFTDIR: u1 = 1,
    PUSH_THRESH: u5 = 0,
    PULL_THRESH: u5 = 0,
    FJOIN_TX: u1 = 0,
    FJOIN_RX: u1 = 0,
};

pub const SM3_PINCTRL = packed struct(u32) {
    OUT_BASE: u5 = 0,
    SET_BASE: u5 = 0,
    SIDESET_BASE: u5 = 0,
    IN_BASE: u5 = 0,
    OUT_COUNT: u6 = 0,
    SET_COUNT: u3 = 5,
    SIDESET_COUNT: u3 = 0,
};

pub const IRQ = packed struct(u32) {
    SM0_RXNEMPTY: u1 = 0,
    SM1_RXNEMPTY: u1 = 0,
    SM2_RXNEMPTY: u1 = 0,
    SM3_RXNEMPTY: u1 = 0,
    SM0_TXNFULL: u1 = 0,
    SM1_TXNFULL: u1 = 0,
    SM2_TXNFULL: u1 = 0,
    SM3_TXNFULL: u1 = 0,
    SM0: u1 = 0,
    SM1: u1 = 0,
    SM2: u1 = 0,
    SM3: u1 = 0,
    _reserved_c: u20 = 0,
};

pub const PIO = extern struct {
    CTRL: Mmio(packed struct(u32) {
        SM_ENABLE: u4 = 0,
        SM_RESTART: u4 = 0,
        CLKDIV_RESTART: u4 = 0,
        _reserved_c: u20 = 0,
    }, .rw),
    FSTAT: Mmio(packed struct(u32) {
        RXFULL: u4 = 0,
        _reserved_4: u4 = 0,
        RXEMPTY: u4 = 0xF,
        _reserved_c: u4 = 0,
        TXFULL: u4 = 0,
        _reserved_14: u4 = 0,
        TXEMPTY: u4 = 0xF,
        _reserved_1c: u4 = 0,
    }, .rw),
    FDEBUG: Mmio(packed struct(u32) {
        RXSTALL: u4 = 0,
        _reserved_4: u4 = 0,
        RXUNDER: u4 = 0,
        _reserved_c: u4 = 0,
        TXOVER: u4 = 0,
        _reserved_14: u4 = 0,
        TXSTALL: u4 = 0,
        _reserved_1c: u4 = 0,
    }, .rw),
    FLEVEL: Mmio(packed struct(u32) {
        TX0: u4 = 0,
        RX0: u4 = 0,
        TX1: u4 = 0,
        RX1: u4 = 0,
        TX2: u4 = 0,
        RX2: u4 = 0,
        TX3: u4 = 0,
        RX3: u4 = 0,
    }, .rw),
    TXF0: Mmio(u32, .w),
    TXF1: Mmio(u32, .w),
    TXF2: Mmio(u32, .w),
    TXF3: Mmio(u32, .w),
    RXF0: Mmio(u32, .r),
    RXF1: Mmio(u32, .r),
    RXF2: Mmio(u32, .r),
    RXF3: Mmio(u32, .r),
    IRQ: Mmio(packed struct(u32) {
        IRQ: u8 = 0,
        _reserved_8: u24 = 0,
    }, .rw),
    IRQ_FORCE: Mmio(packed struct(u32) {
        IRQ_FORCE: u8 = 0,
        _reserved_8: u24 = 0,
    }, .rw),
    INPUT_SYNC_BYPASS: Mmio(u32, .rw),
    DBG_PADOUT: Mmio(u32, .r),
    DBG_PADOE: Mmio(u32, .r),
    DBG_CFGINFO: Mmio(packed struct(u32) {
        FIFO_DEPTH: u6 = 0,
        _reserved_6: u2 = 0,
        SM_COUNT: u4 = 0,
        _reserved_c: u4 = 0,
        IMEM_SIZE: u6 = 0,
        _reserved_16: u10 = 0,
    }, .rw),
    INSTR_MEM0: Mmio(packed struct(u32) {
        INSTR_MEM0: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM1: Mmio(packed struct(u32) {
        INSTR_MEM1: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM2: Mmio(packed struct(u32) {
        INSTR_MEM2: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM3: Mmio(packed struct(u32) {
        INSTR_MEM3: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM4: Mmio(packed struct(u32) {
        INSTR_MEM4: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM5: Mmio(packed struct(u32) {
        INSTR_MEM5: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM6: Mmio(packed struct(u32) {
        INSTR_MEM6: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM7: Mmio(packed struct(u32) {
        INSTR_MEM7: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM8: Mmio(packed struct(u32) {
        INSTR_MEM8: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM9: Mmio(packed struct(u32) {
        INSTR_MEM9: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM10: Mmio(packed struct(u32) {
        INSTR_MEM10: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM11: Mmio(packed struct(u32) {
        INSTR_MEM11: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM12: Mmio(packed struct(u32) {
        INSTR_MEM12: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM13: Mmio(packed struct(u32) {
        INSTR_MEM13: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM14: Mmio(packed struct(u32) {
        INSTR_MEM14: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM15: Mmio(packed struct(u32) {
        INSTR_MEM15: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM16: Mmio(packed struct(u32) {
        INSTR_MEM16: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM17: Mmio(packed struct(u32) {
        INSTR_MEM17: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM18: Mmio(packed struct(u32) {
        INSTR_MEM18: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM19: Mmio(packed struct(u32) {
        INSTR_MEM19: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM20: Mmio(packed struct(u32) {
        INSTR_MEM20: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM21: Mmio(packed struct(u32) {
        INSTR_MEM21: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM22: Mmio(packed struct(u32) {
        INSTR_MEM22: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM23: Mmio(packed struct(u32) {
        INSTR_MEM23: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM24: Mmio(packed struct(u32) {
        INSTR_MEM24: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM25: Mmio(packed struct(u32) {
        INSTR_MEM25: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM26: Mmio(packed struct(u32) {
        INSTR_MEM26: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM27: Mmio(packed struct(u32) {
        INSTR_MEM27: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM28: Mmio(packed struct(u32) {
        INSTR_MEM28: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM29: Mmio(packed struct(u32) {
        INSTR_MEM29: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM30: Mmio(packed struct(u32) {
        INSTR_MEM30: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    INSTR_MEM31: Mmio(packed struct(u32) {
        INSTR_MEM31: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    SM0_CLKDIV: Mmio(SM3_CLKDIV, .rw),
    SM0_EXECCTRL: Mmio(SM3_EXECCTRL, .rw),
    SM0_SHIFTCTRL: Mmio(SM3_SHIFTCTRL, .rw),
    SM0_ADDR: Mmio(packed struct(u32) {
        SM0_ADDR: u5 = 0,
        _reserved_5: u27 = 0,
    }, .rw),
    SM0_INSTR: Mmio(packed struct(u32) {
        SM0_INSTR: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    SM0_PINCTRL: Mmio(SM3_PINCTRL, .rw),
    SM1_CLKDIV: Mmio(SM3_CLKDIV, .rw),
    SM1_EXECCTRL: Mmio(SM3_EXECCTRL, .rw),
    SM1_SHIFTCTRL: Mmio(SM3_SHIFTCTRL, .rw),
    SM1_ADDR: Mmio(packed struct(u32) {
        SM1_ADDR: u5 = 0,
        _reserved_5: u27 = 0,
    }, .rw),
    SM1_INSTR: Mmio(packed struct(u32) {
        SM1_INSTR: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    SM1_PINCTRL: Mmio(SM3_PINCTRL, .rw),
    SM2_CLKDIV: Mmio(SM3_CLKDIV, .rw),
    SM2_EXECCTRL: Mmio(SM3_EXECCTRL, .rw),
    SM2_SHIFTCTRL: Mmio(SM3_SHIFTCTRL, .rw),
    SM2_ADDR: Mmio(packed struct(u32) {
        SM2_ADDR: u5 = 0,
        _reserved_5: u27 = 0,
    }, .rw),
    SM2_INSTR: Mmio(packed struct(u32) {
        SM2_INSTR: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    SM2_PINCTRL: Mmio(SM3_PINCTRL, .rw),
    SM3_CLKDIV: Mmio(SM3_CLKDIV, .rw),
    SM3_EXECCTRL: Mmio(SM3_EXECCTRL, .rw),
    SM3_SHIFTCTRL: Mmio(SM3_SHIFTCTRL, .rw),
    SM3_ADDR: Mmio(packed struct(u32) {
        SM3_ADDR: u5 = 0,
        _reserved_5: u27 = 0,
    }, .rw),
    SM3_INSTR: Mmio(packed struct(u32) {
        SM3_INSTR: u16 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    SM3_PINCTRL: Mmio(SM3_PINCTRL, .rw),
    INTR: Mmio(IRQ, .rw),
    IRQ0_INTE: Mmio(IRQ, .rw),
    IRQ0_INTF: Mmio(IRQ, .rw),
    IRQ0_INTS: Mmio(IRQ, .rw),
    IRQ1_INTE: Mmio(IRQ, .rw),
    IRQ1_INTF: Mmio(IRQ, .rw),
    IRQ1_INTS: Mmio(IRQ, .rw),
};
