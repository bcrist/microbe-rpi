// Generated by https://github.com/bcrist/microbe-regz
const microbe = @import("microbe");
const chip = @import("chip");
const MMIO = microbe.MMIO;

pub const SYSCFG = extern struct {
    PROC0_NMI_MASK: MMIO(u32, .rw),
    PROC1_NMI_MASK: MMIO(u32, .rw),
    PROC_CONFIG: MMIO(packed struct(u32) {
        PROC0_HALTED: u1 = 0,
        PROC1_HALTED: u1 = 0,
        _reserved_2: u22 = 0,
        PROC0_DAP_INSTID: u4 = 0,
        PROC1_DAP_INSTID: u4 = 1,
    }, .rw),
    PROC_IN_SYNC_BYPASS: MMIO(packed struct(u32) {
        PROC_IN_SYNC_BYPASS: u30 = 0,
        _reserved_1e: u2 = 0,
    }, .rw),
    PROC_IN_SYNC_BYPASS_HI: MMIO(packed struct(u32) {
        PROC_IN_SYNC_BYPASS_HI: u6 = 0,
        _reserved_6: u26 = 0,
    }, .rw),
    DBGFORCE: MMIO(packed struct(u32) {
        PROC0_SWDO: u1 = 0,
        PROC0_SWDI: u1 = 1,
        PROC0_SWCLK: u1 = 1,
        PROC0_ATTACH: u1 = 0,
        PROC1_SWDO: u1 = 0,
        PROC1_SWDI: u1 = 1,
        PROC1_SWCLK: u1 = 1,
        PROC1_ATTACH: u1 = 0,
        _reserved_8: u24 = 0,
    }, .rw),
    MEMPOWERDOWN: MMIO(packed struct(u32) {
        SRAM0: u1 = 0,
        SRAM1: u1 = 0,
        SRAM2: u1 = 0,
        SRAM3: u1 = 0,
        SRAM4: u1 = 0,
        SRAM5: u1 = 0,
        USB: u1 = 0,
        ROM: u1 = 0,
        _reserved_8: u24 = 0,
    }, .rw),
};

pub const VREG_AND_CHIP_RESET = extern struct {
    VREG: MMIO(packed struct(u32) {
        EN: u1 = 1,
        HIZ: u1 = 0,
        _reserved_2: u2 = 0,
        VSEL: u4 = 0xB,
        _reserved_8: u4 = 0,
        ROK: u1 = 0,
        _reserved_d: u19 = 0,
    }, .rw),
    BOD: MMIO(packed struct(u32) {
        EN: u1 = 1,
        _reserved_1: u3 = 0,
        VSEL: u4 = 9,
        _reserved_8: u24 = 0,
    }, .rw),
    CHIP_RESET: MMIO(packed struct(u32) {
        _reserved_0: u8 = 0,
        HAD_POR: u1 = 0,
        _reserved_9: u7 = 0,
        HAD_RUN: u1 = 0,
        _reserved_11: u3 = 0,
        HAD_PSM_RESTART: u1 = 0,
        _reserved_15: u3 = 0,
        PSM_RESTART_FLAG: u1 = 0,
        _reserved_19: u7 = 0,
    }, .rw),
};

pub const PERFSEL = enum(u5) {
    apb_contested = 0x0,
    apb = 0x1,
    fastperi_contested = 0x2,
    fastperi = 0x3,
    sram5_contested = 0x4,
    sram5 = 0x5,
    sram4_contested = 0x6,
    sram4 = 0x7,
    sram3_contested = 0x8,
    sram3 = 0x9,
    sram2_contested = 0xA,
    sram2 = 0xB,
    sram1_contested = 0xC,
    sram1 = 0xD,
    sram0_contested = 0xE,
    sram0 = 0xF,
    xip_main_contested = 0x10,
    xip_main = 0x11,
    rom_contested = 0x12,
    rom = 0x13,
    _,
};

pub const BUSCTRL = extern struct {
    BUS_PRIORITY: MMIO(packed struct(u32) {
        PROC0: u1 = 0,
        _reserved_1: u3 = 0,
        PROC1: u1 = 0,
        _reserved_5: u3 = 0,
        DMA_R: u1 = 0,
        _reserved_9: u3 = 0,
        DMA_W: u1 = 0,
        _reserved_d: u19 = 0,
    }, .rw),
    BUS_PRIORITY_ACK: MMIO(packed struct(u32) {
        BUS_PRIORITY_ACK: u1 = 0,
        _reserved_1: u31 = 0,
    }, .rw),
    PERFCTR0: MMIO(packed struct(u32) {
        PERFCTR0: u24 = 0,
        _reserved_18: u8 = 0,
    }, .rw),
    PERFSEL0: MMIO(packed struct(u32) {
        PERFSEL0: PERFSEL = @enumFromInt(31),
        _reserved_5: u27 = 0,
    }, .rw),
    PERFCTR1: MMIO(packed struct(u32) {
        PERFCTR1: u24 = 0,
        _reserved_18: u8 = 0,
    }, .rw),
    PERFSEL1: MMIO(packed struct(u32) {
        PERFSEL1: PERFSEL = @enumFromInt(31),
        _reserved_5: u27 = 0,
    }, .rw),
    PERFCTR2: MMIO(packed struct(u32) {
        PERFCTR2: u24 = 0,
        _reserved_18: u8 = 0,
    }, .rw),
    PERFSEL2: MMIO(packed struct(u32) {
        PERFSEL2: PERFSEL = @enumFromInt(31),
        _reserved_5: u27 = 0,
    }, .rw),
    PERFCTR3: MMIO(packed struct(u32) {
        PERFCTR3: u24 = 0,
        _reserved_18: u8 = 0,
    }, .rw),
    PERFSEL3: MMIO(packed struct(u32) {
        PERFSEL3: PERFSEL = @enumFromInt(31),
        _reserved_5: u27 = 0,
    }, .rw),
};

pub const DONE = packed struct(u32) {
    rosc: u1 = 0,
    xosc: u1 = 0,
    clocks: u1 = 0,
    resets: u1 = 0,
    busfabric: u1 = 0,
    rom: u1 = 0,
    sram0: u1 = 0,
    sram1: u1 = 0,
    sram2: u1 = 0,
    sram3: u1 = 0,
    sram4: u1 = 0,
    sram5: u1 = 0,
    xip: u1 = 0,
    vreg_and_chip_reset: u1 = 0,
    sio: u1 = 0,
    proc0: u1 = 0,
    proc1: u1 = 0,
    _reserved_11: u15 = 0,
};

pub const PSM = extern struct {
    FRCE_ON: MMIO(DONE, .rw),
    FRCE_OFF: MMIO(DONE, .rw),
    WDSEL: MMIO(DONE, .rw),
    DONE: MMIO(DONE, .rw),
};

pub const XIP_CTRL = extern struct {
    CTRL: MMIO(packed struct(u32) {
        EN: u1 = 1,
        ERR_BADWRITE: u1 = 1,
        _reserved_2: u1 = 0,
        POWER_DOWN: u1 = 0,
        _reserved_4: u28 = 0,
    }, .rw),
    FLUSH: MMIO(packed struct(u32) {
        FLUSH: u1 = 0,
        _reserved_1: u31 = 0,
    }, .rw),
    STAT: MMIO(packed struct(u32) {
        FLUSH_READY: u1 = 0,
        FIFO_EMPTY: u1 = 1,
        FIFO_FULL: u1 = 0,
        _reserved_3: u29 = 0,
    }, .rw),
    CTR_HIT: MMIO(u32, .rw),
    CTR_ACC: MMIO(u32, .rw),
    STREAM_ADDR: MMIO(packed struct(u32) {
        _reserved_0: u2 = 0,
        STREAM_ADDR: u30 = 0,
    }, .rw),
    STREAM_CTR: MMIO(packed struct(u32) {
        STREAM_CTR: u22 = 0,
        _reserved_16: u10 = 0,
    }, .rw),
    STREAM_FIFO: MMIO(u32, .r),
};

pub const Reset_Bitmap = packed struct(u32) {
    adc: bool = false,
    busctrl: bool = false,
    dma: bool = false,
    i2c0: bool = false,
    i2c1: bool = false,
    io_bank0: bool = false,
    io_qspi: bool = false,
    jtag: bool = false,
    pads_bank0: bool = false,
    pads_qspi: bool = false,
    pio0: bool = false,
    pio1: bool = false,
    pll_sys: bool = false,
    pll_usb: bool = false,
    pwm: bool = false,
    rtc: bool = false,
    spi0: bool = false,
    spi1: bool = false,
    syscfg: bool = false,
    sysinfo: bool = false,
    tbman: bool = false,
    timer: bool = false,
    uart0: bool = false,
    uart1: bool = false,
    usbctrl: bool = false,
    _reserved_19: u7 = 0,
};

pub const RESETS = extern struct {
    force: MMIO(Reset_Bitmap, .rw),
    watchdog: MMIO(Reset_Bitmap, .rw),
    done: MMIO(Reset_Bitmap, .rw),
};

pub const Value_Set_Clear_Toggle = extern struct {
    value: MMIO(u32, .rw),
    set: MMIO(u32, .w),
    clear: MMIO(u32, .w),
    toggle: MMIO(u32, .w),
};

pub const SIO = extern struct {
    core_id: MMIO(u32, .r),
    io: extern struct {
        in: MMIO(u32, .r),
        in_qspi: MMIO(u32, .r),
        _reserved_8: [4]u8 = undefined,
        out: Value_Set_Clear_Toggle,
        oe: Value_Set_Clear_Toggle,
        out_qspi: Value_Set_Clear_Toggle,
        oe_qspi: Value_Set_Clear_Toggle,
    },
    fifo: extern struct {
        status: MMIO(packed struct(u32) {
            /// inbox can be read at least once
            readable: bool = false,

            /// outbox can be written at least once
            writable: bool = false,

            /// was written when full; write to clear
            write_error_flag: bool = false,

            /// was read when empty; write to clear
            read_error_flag: bool = false,

            _reserved_4: u28 = 0,
        }, .rw),
        outbox: MMIO(u32, .w),
        inbox: MMIO(u32, .r),
    },
    spinlock_status: MMIO(u32, .r),
    divider: extern struct {
        unsigned_dividend: MMIO(u32, .rw),
        unsigned_divisor: MMIO(u32, .rw),
        signed_dividend: MMIO(i32, .rw),
        signed_divisor: MMIO(i32, .rw),
        quotient: MMIO(u32, .r),
        remainder: MMIO(u32, .r),
        control_status: MMIO(packed struct(u32) {
            ready: bool = false,
            dirty: bool = false,
            _reserved_2: u30 = 0,
        }, .r),
    },
    _reserved_7c: [4]u8 = undefined,
    interpolator: [2]extern struct {
        accumulator: [2]MMIO(u32, .rw),
        base: [3]MMIO(u32, .rw),
        pop_lane0: MMIO(u32, .r),
        pop_lane1: MMIO(u32, .r),
        pop_full: MMIO(u32, .r),
        peek_lane0: MMIO(u32, .r),
        peek_lane1: MMIO(u32, .r),
        peek_full: MMIO(u32, .r),
        control_lane0: MMIO(packed struct(u32) {
            shift: u5 = 0,
            mask_lsb: u5 = 0,
            mask_msb: u5 = 0,
            signed: bool = false,
            cross_input: bool = false,
            cross_result: bool = false,
            overflow0: bool = false,
            add_raw: bool = false,
            overflow1: bool = false,
            force_msb: u2 = 0,
            overflow: bool = false,

            /// only for interpolator 0
            blend: bool = false,

            _reserved_19: u7 = 0,
        }, .rw),
        control_lane1: MMIO(packed struct(u32) {
            shift: u5 = 0,
            mask_lsb: u5 = 0,
            mask_msb: u5 = 0,
            signed: bool = false,
            cross_input: bool = false,
            cross_result: bool = false,
            add_raw: bool = false,
            force_msb: u2 = 0,
            _reserved_15: u11 = 0,
        }, .rw),
        accumulator_add: [2]MMIO(packed struct(u32) {
            value: u24 = 0,
            _reserved_18: u8 = 0,
        }, .rw),
        base_split_write: MMIO(packed struct(u32) {
            base0: i16 = 0,
            base1: i16 = 0,
        }, .w),
    },
    spinlock: [32]MMIO(u32, .rw),
};

pub const WATCHDOG = extern struct {
    control: MMIO(packed struct(u32) {
        ticks_remaining_x2: u24 = 0,
        pause_during_jtag: bool = true,
        pause_when_core0_debugging: bool = true,
        pause_when_core1_debugging: bool = true,
        _reserved_1b: u3 = 0,
        enable_countdown: bool = false,
        trigger_immediately: bool = false,
    }, .rw),
    reload: MMIO(packed struct(u32) {
        ticks_x2: u24 = 0,
        _reserved_18: u8 = 0,
    }, .rw),
    last_reset_reason: MMIO(packed struct(u32) {
        reason: enum(u2) {
            chip_reset = 0,
            watchdog_timeout = 1,
            watchdog_forced = 2,
            _,
        } = .chip_reset,
        _reserved_2: u30 = 0,
    }, .rw),
    scratch: [8]MMIO(u32, .rw),
    tick: MMIO(packed struct(u32) {
        divisor: u9 = 0,
        enabled: bool = true,
        running: bool = false,
        current_count: u9 = 0,
        _reserved_14: u12 = 0,
    }, .rw),
};

pub const SSI = extern struct {
    control_0: MMIO(packed struct(u32) {
        _reserved_0: u4 = 0,
        frame_format: enum(u2) {
            spi = 0,
            ssp = 1,
            microwire = 2,
            _,
        } = .spi,
        clock_phase: u1 = 0,
        clock_polarity: u1 = 0,
        transfer_mode: enum(u2) {
            tx_and_rx = 0,

            /// not for SPI_frame_format == .standard
            tx_only = 1,

            /// not for SPI_frame_format == .standard
            rx_only = 2,

            /// tx then rx
            eeprom_read = 3,
        } = .tx_and_rx,
        slave_output_enable: u1 = 0,

        /// test mode
        shift_register_loop: u1 = 0,

        control_frame_size: enum(u4) {
            _1_bit = 0,
            _2_bits = 1,
            _3_bits = 2,
            _4_bits = 3,
            _5_bits = 4,
            _6_bits = 5,
            _7_bits = 6,
            _8_bits = 7,
            _9_bits = 8,
            _10_bits = 9,
            _11_bits = 10,
            _12_bits = 11,
            _13_bits = 12,
            _14_bits = 13,
            _15_bits = 14,
            _16_bits = 15,
        } = ._1_bit,
        data_frame_size: enum(u5) {
            _1_bit = 0x0,
            _2_bits = 0x1,
            _3_bits = 0x2,
            _4_bits = 0x3,
            _5_bits = 0x4,
            _6_bits = 0x5,
            _7_bits = 0x6,
            _8_bits = 0x7,
            _9_bits = 0x8,
            _10_bits = 0x9,
            _11_bits = 0xA,
            _12_bits = 0xB,
            _13_bits = 0xC,
            _14_bits = 0xD,
            _15_bits = 0xE,
            _16_bits = 0xF,
            _17_bits = 0x10,
            _18_bits = 0x11,
            _19_bits = 0x12,
            _20_bits = 0x13,
            _21_bits = 0x14,
            _22_bits = 0x15,
            _23_bits = 0x16,
            _24_bits = 0x17,
            _25_bits = 0x18,
            _26_bits = 0x19,
            _27_bits = 0x1A,
            _28_bits = 0x1B,
            _29_bits = 0x1C,
            _30_bits = 0x1D,
            _31_bits = 0x1E,
            _32_bits = 0x1F,
        } = ._1_bit,

        /// Only valid when frame_format is .spi
        spi_frame_format: enum(u2) {
            standard = 0,
            dual = 1,
            quad = 2,
            _,
        } = .standard,

        _reserved_17: u1 = 0,
        slave_select_toggle_enable: u1 = 0,
        _reserved_19: u7 = 0,
    }, .rw),
    control_1: MMIO(packed struct(u32) {
        /// N+1 data frames will be transferred
        num_data_frames: u16 = 0,

        _reserved_10: u16 = 0,
    }, .rw),
    enable: MMIO(packed struct(u32) {
        enable: bool = false,
        _reserved_1: u31 = 0,
    }, .rw),
    MWCR: MMIO(packed struct(u32) {
        MWMOD: u1 = 0,
        MDD: u1 = 0,
        MHS: u1 = 0,
        _reserved_3: u29 = 0,
    }, .rw),
    SER: MMIO(packed struct(u32) {
        SER: u1 = 0,
        _reserved_1: u31 = 0,
    }, .rw),
    baud_rate: MMIO(packed struct(u32) {
        /// LSB must be 0
        clock_divisor: u16 = 0,

        _reserved_10: u16 = 0,
    }, .rw),
    TXFTLR: MMIO(packed struct(u32) {
        TFT: u8 = 0,
        _reserved_8: u24 = 0,
    }, .rw),
    RXFTLR: MMIO(packed struct(u32) {
        RFT: u8 = 0,
        _reserved_8: u24 = 0,
    }, .rw),
    TXFLR: MMIO(packed struct(u32) {
        TFTFL: u8 = 0,
        _reserved_8: u24 = 0,
    }, .rw),
    RXFLR: MMIO(packed struct(u32) {
        RXTFL: u8 = 0,
        _reserved_8: u24 = 0,
    }, .rw),
    status: MMIO(packed struct(u32) {
        busy: bool = false,
        tx_fifo_not_full: bool = false,
        tx_fifo_empty: bool = false,
        rx_fifo_not_empty: bool = false,
        rx_fifo_full: bool = false,
        tx_error_flag: bool = false,
        data_collision_error_flag: bool = false,
        _reserved_7: u25 = 0,
    }, .r),
    IMR: MMIO(packed struct(u32) {
        TXEIM: u1 = 0,
        TXOIM: u1 = 0,
        RXUIM: u1 = 0,
        RXOIM: u1 = 0,
        RXFIM: u1 = 0,
        MSTIM: u1 = 0,
        _reserved_6: u26 = 0,
    }, .rw),
    ISR: MMIO(packed struct(u32) {
        TXEIS: u1 = 0,
        TXOIS: u1 = 0,
        RXUIS: u1 = 0,
        RXOIS: u1 = 0,
        RXFIS: u1 = 0,
        MSTIS: u1 = 0,
        _reserved_6: u26 = 0,
    }, .rw),
    RISR: MMIO(packed struct(u32) {
        TXEIR: u1 = 0,
        TXOIR: u1 = 0,
        RXUIR: u1 = 0,
        RXOIR: u1 = 0,
        RXFIR: u1 = 0,
        MSTIR: u1 = 0,
        _reserved_6: u26 = 0,
    }, .rw),
    TXOICR: MMIO(packed struct(u32) {
        TXOICR: u1 = 0,
        _reserved_1: u31 = 0,
    }, .rw),
    RXOICR: MMIO(packed struct(u32) {
        RXOICR: u1 = 0,
        _reserved_1: u31 = 0,
    }, .rw),
    RXUICR: MMIO(packed struct(u32) {
        RXUICR: u1 = 0,
        _reserved_1: u31 = 0,
    }, .rw),
    MSTICR: MMIO(packed struct(u32) {
        MSTICR: u1 = 0,
        _reserved_1: u31 = 0,
    }, .rw),
    ICR: MMIO(packed struct(u32) {
        ICR: u1 = 0,
        _reserved_1: u31 = 0,
    }, .rw),
    DMACR: MMIO(packed struct(u32) {
        RDMAE: u1 = 0,
        TDMAE: u1 = 0,
        _reserved_2: u30 = 0,
    }, .rw),
    DMATDLR: MMIO(packed struct(u32) {
        DMATDL: u8 = 0,
        _reserved_8: u24 = 0,
    }, .rw),
    DMARDLR: MMIO(packed struct(u32) {
        DMARDL: u8 = 0,
        _reserved_8: u24 = 0,
    }, .rw),
    IDR: MMIO(u32, .rw),
    SSI_VERSION_ID: MMIO(u32, .rw),
    data: [36]MMIO(u32, .rw),
    rx_sample_delay: MMIO(packed struct(u32) {
        delay: u8 = 0,
        _reserved_8: u24 = 0,
    }, .rw),
    spi_control: MMIO(packed struct(u32) {
        transfer_format: enum(u2) {
            standard_command_standard_address = 0,
            standard_command_wide_address = 1,
            wide_command_wide_address = 2,
            _,
        } = .standard_command_standard_address,
        address_length: enum(u4) {
            none = 0,
            _4_bits = 1,
            _8_bits = 2,
            _12_bits = 3,
            _16_bits = 4,
            _20_bits = 5,
            _24_bits = 6,
            _28_bits = 7,
            _32_bits = 8,
            _36_bits = 9,
            _40_bits = 10,
            _44_bits = 11,
            _48_bits = 12,
            _52_bits = 13,
            _56_bits = 14,
            _60_bits = 15,
        } = .none,
        _reserved_6: u2 = 0,
        command_length: enum(u2) {
            none = 0,
            _4_bits = 1,
            _8_bits = 2,
            _16_bits = 3,
        } = .none,
        _reserved_a: u1 = 0,
        wait_cycles_after_mode: u5 = 0,
        ddr_address_and_data: bool = false,
        ddr_command: bool = false,
        enable_read_data_strobe: bool = false,
        _reserved_13: u5 = 0,

        /// When command_length is 8 bits, this command is sent for each XIP transfer.
        /// When command_length is 0, it is appended to the address.
        xip_command_or_mode: u8 = 3,
    }, .rw),
    TXD_DRIVE_EDGE: MMIO(packed struct(u32) {
        TDE: u8 = 0,
        _reserved_8: u24 = 0,
    }, .rw),
};

pub const SYSINFO = extern struct {
    chip_id: MMIO(packed struct(u32) {
        mfr: u12 = 0,
        part: u16 = 0,
        revision: u4 = 0,
    }, .rw),
    _reserved_4: [60]u8 = undefined,
    git_revision: MMIO(u32, .r),
};
