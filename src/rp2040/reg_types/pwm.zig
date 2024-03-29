// Generated by https://github.com/bcrist/microbe-regz
const microbe = @import("microbe");
const chip = @import("chip");
const MMIO = microbe.MMIO;

pub const Channel_Bitmap = packed struct(u32) {
    ch0: bool = false,
    ch1: bool = false,
    ch2: bool = false,
    ch3: bool = false,
    ch4: bool = false,
    ch5: bool = false,
    ch6: bool = false,
    ch7: bool = false,
    _reserved_8: u24 = 0,
};

pub const PWM = extern struct {
    channel: [8]extern struct {
        control: MMIO(packed struct(u32) {
            enabled: bool = false,
            phase_correct: bool = false,
            invert_a: bool = false,
            invert_b: bool = false,
            clock_mode: enum(u2) {
                free_running = 0,
                gated = 1,
                rising_edge = 2,
                falling_edge = 3,
            } = .free_running,
            request_phase_retard: bool = false,
            request_phase_advance: bool = false,
            _reserved_8: u24 = 0,
        }, .rw),
        divisor: MMIO(packed struct(u32) {
            div_16ths: u12 = 0x10,
            _reserved_c: u20 = 0,
        }, .rw),
        counter: MMIO(packed struct(u32) {
            count: u16 = 0,
            _reserved_10: u16 = 0,
        }, .rw),
        compare: MMIO(packed struct(u32) {
            a: u16 = 0,
            b: u16 = 0,
        }, .rw),
        top: MMIO(packed struct(u32) {
            count: u16 = 0xFFFF,
            _reserved_10: u16 = 0,
        }, .rw),
    },
    enable: MMIO(Channel_Bitmap, .rw),
    irq: extern struct {
        raw: MMIO(Channel_Bitmap, .rw),
        enable: MMIO(Channel_Bitmap, .rw),
        force: MMIO(Channel_Bitmap, .rw),
        status: MMIO(Channel_Bitmap, .r),
    },
};
