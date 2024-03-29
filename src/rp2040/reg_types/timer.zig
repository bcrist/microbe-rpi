// Generated by https://github.com/bcrist/microbe-regz
const microbe = @import("microbe");
const chip = @import("chip");
const MMIO = microbe.MMIO;

pub const Alarm_Bitmap = packed struct(u32) {
    alarm0: bool = false,
    alarm1: bool = false,
    alarm2: bool = false,
    alarm3: bool = false,
    _reserved_4: u28 = 0,
};

pub const TIMER = extern struct {
    write_tick: extern struct {
        high: MMIO(u32, .w),
        low: MMIO(u32, .w),
    },
    read_tick: extern struct {
        /// read low first to latch
        high: MMIO(u32, .r),

        /// high is latched when read
        low: MMIO(u32, .r),
    },
    alarm_tick: [4]MMIO(u32, .rw),
    alarm: extern union {
        pending: MMIO(Alarm_Bitmap, .r),
        cancel: MMIO(Alarm_Bitmap, .w),
    },
    read_tick_unlatched: extern struct {
        high: MMIO(u32, .r),
        low: MMIO(u32, .r),
    },
    debug: MMIO(packed struct(u32) {
        _reserved_0: u1 = 0,
        pause_when_core0_halted: bool = true,
        pause_when_core1_halted: bool = true,
        _reserved_3: u29 = 0,
    }, .rw),
    control: MMIO(packed struct(u32) {
        pause: bool = false,
        _reserved_1: u31 = 0,
    }, .rw),
    interrupt_status: MMIO(Alarm_Bitmap, .rw),
    irq: extern struct {
        enable: MMIO(Alarm_Bitmap, .rw),
        force: MMIO(Alarm_Bitmap, .rw),
        status: MMIO(Alarm_Bitmap, .r),
    },
};
