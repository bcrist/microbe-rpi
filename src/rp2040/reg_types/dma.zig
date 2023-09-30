// Generated by https://github.com/bcrist/microbe-regz
const Mmio = @import("microbe").Mmio;

pub const ChannelBitmap = packed struct(u32) {
    channel_0: bool = false,
    channel_1: bool = false,
    channel_2: bool = false,
    channel_3: bool = false,
    channel_4: bool = false,
    channel_5: bool = false,
    channel_6: bool = false,
    channel_7: bool = false,
    channel_8: bool = false,
    channel_9: bool = false,
    channel_10: bool = false,
    channel_11: bool = false,
    _reserved_c: u20 = 0,
};

pub const InterruptEnableForceStatus = extern struct {
    enable: Mmio(ChannelBitmap, .rw),
    force: Mmio(ChannelBitmap, .rw),
    status: Mmio(ChannelBitmap, .rw),
};

pub const ChannelControl = packed struct(u32) {
    enabled: u1 = 0,
    priority: enum(u1) {
        low = 0,
        high = 1,
    } = .low,
    width: enum(u2) {
        _8_bits = 0,
        _16_bits = 1,
        _32_bits = 2,
        _,
    } = ._8_bits,
    increment_after_read: bool = false,
    increment_after_write: bool = false,
    circular_buffer_align: enum(u4) {
        no_wrap = 0,
        _2_bytes = 1,
        _4_bytes = 2,
        _8_bytes = 3,
        _16_bytes = 4,
        _32_bytes = 5,
        _64_bytes = 6,
        _128_bytes = 7,
        _256_bytes = 8,
        _512_bytes = 9,
        _1024_bytes = 10,
        _2048_bytes = 11,
        _4096_bytes = 12,
        _8192_bytes = 13,
        _16384_bytes = 14,
        _32768_bytes = 15,
    } = .no_wrap,
    circular_buffer_mode: enum(u1) {
        circular_buffer_source = 0,
        circular_buffer_dest = 1,
    } = .circular_buffer_source,

    /// Set to own channel ID to disable
    chain_channel: u4 = 0,

    handshake: enum(u6) {
        pio0_tx0 = 0x0,
        pio0_tx1 = 0x1,
        pio0_tx2 = 0x2,
        pio0_tx3 = 0x3,
        pio0_rx0 = 0x4,
        pio0_rx1 = 0x5,
        pio0_rx2 = 0x6,
        pio0_rx3 = 0x7,
        pio1_tx0 = 0x8,
        pio1_tx1 = 0x9,
        pio1_tx2 = 0xA,
        pio1_tx3 = 0xB,
        pio1_rx0 = 0xC,
        pio1_rx1 = 0xD,
        pio1_rx2 = 0xE,
        pio1_rx3 = 0xF,
        spi0_tx = 0x10,
        spi0_rx = 0x11,
        spi1_tx = 0x12,
        spi1_rx = 0x13,
        uart0_tx = 0x14,
        uart0_rx = 0x15,
        uart1_tx = 0x16,
        uart1_rx = 0x17,
        pwm_wrap0 = 0x18,
        pwm_wrap1 = 0x19,
        pwm_wrap2 = 0x1A,
        pwm_wrap3 = 0x1B,
        pwm_wrap4 = 0x1C,
        pwm_wrap5 = 0x1D,
        pwm_wrap6 = 0x1E,
        pwm_wrap7 = 0x1F,
        i2c0_tx = 0x20,
        i2c0_rx = 0x21,
        i2c1_tx = 0x22,
        i2c1_rx = 0x23,
        adc = 0x24,
        xip_stream = 0x25,
        xip_ssitx = 0x26,
        xip_ssirx = 0x27,
        pacer0 = 0x3B,
        pacer1 = 0x3C,
        pacer2 = 0x3D,
        pacer3 = 0x3E,
        none = 0x3F,
        _,
    } = .none,
    interrupt_mode: enum(u1) {
        transfer_complete = 0,
        null_trigger = 1,
    } = .transfer_complete,
    byteswap: bool = false,
    checksum_enabled: bool = false,
    busy: bool = false,
    _reserved_19: u4 = 0,

    /// write 1 to clear
    write_error_flag: bool = false,

    /// write 1 to clear
    read_error_flag: bool = false,

    /// logical OR or write_error_flag and read_error_flag
    bus_error_flag: bool = false,
};

pub const DMA = extern struct {
    interrupt_status: Mmio(ChannelBitmap, .rw),
    irq0: InterruptEnableForceStatus,
    _reserved_10: [4]u8 = undefined,
    irq1: InterruptEnableForceStatus,
    pacer: [4]Mmio(packed struct(u32) {
        divisor: u16 = 0,
        multiplier: u16 = 0,
    }, .rw),
    multi_trigger: Mmio(ChannelBitmap, .w),
    checksum: extern struct {
        control: Mmio(packed struct(u32) {
            enabled: bool = false,
            channel: u4 = 0,
            algorithm: enum(u4) {
                crc32_ieee802_3 = 0,
                crc32_ieee802_3_bitswapped = 1,
                crc16_ccitt = 2,
                crc16_ccitt_bitswapped = 3,
                parity = 14,
                sum32 = 15,
                _,
            } = .crc32_ieee802_3,

            /// applies after the byteswap from channel config
            byteswap: bool = false,

            output_bitswapped: bool = false,
            output_complemented: bool = false,
            _reserved_c: u20 = 0,
        }, .rw),
        data: Mmio(u32, .rw),
    },
    _reserved_3c: [4]u8 = undefined,
    fifo_debug: Mmio(packed struct(u32) {
        data_fifo_level: u8 = 0,
        write_address_fifo_level: u8 = 0,
        read_address_fifo_level: u8 = 0,
        _reserved_18: u8 = 0,
    }, .r),

    /// N.B. erratum RP2040-E13
    abort: Mmio(ChannelBitmap, .w),
};

pub const DMA_CH = [12]union {
    config: extern struct {
        /// N.B. erratum RP2040-E12
        read_ptr: Mmio(*allowzero const anyopaque, .rw),

        /// N.B. erratum RP2040-E12
        write_ptr: Mmio(*allowzero anyopaque, .rw),

        /// Writes will not take effect until the next time the channel is triggered
        count: Mmio(u32, .rw),

        _reserved_c: [4]u8 = undefined,
        control: Mmio(ChannelControl, .rw),
    },
    trigger: extern struct {
        _reserved_0: [12]u8 = undefined,
        control: Mmio(ChannelControl, .rw),
        _reserved_10: [12]u8 = undefined,
        count: Mmio(u32, .rw),
        _reserved_20: [12]u8 = undefined,
        write_ptr: Mmio(*allowzero anyopaque, .rw),
        _reserved_30: [12]u8 = undefined,
        read_ptr: Mmio(*allowzero const anyopaque, .rw),
    },
    config_block: extern struct {
        control_triggered: extern struct {
            /// N.B. erratum RP2040-E12
            read_ptr: Mmio(*allowzero const anyopaque, .rw),

            /// N.B. erratum RP2040-E12
            write_ptr: Mmio(*allowzero anyopaque, .rw),

            /// Writes will not take effect until the next time the channel is triggered
            count: Mmio(u32, .rw),

            control: Mmio(ChannelControl, .rw),
        },
        count_triggered: extern struct {
            control: Mmio(ChannelControl, .rw),

            /// N.B. erratum RP2040-E12
            read_ptr: Mmio(*allowzero const anyopaque, .rw),

            /// N.B. erratum RP2040-E12
            write_ptr: Mmio(*allowzero anyopaque, .rw),

            count: Mmio(u32, .rw),
        },
        write_ptr_triggered: extern struct {
            control: Mmio(ChannelControl, .rw),
            count: Mmio(u32, .rw),

            /// N.B. erratum RP2040-E12
            read_ptr: Mmio(*allowzero const anyopaque, .rw),

            /// N.B. erratum RP2040-E12
            write_ptr: Mmio(*allowzero anyopaque, .rw),
        },
        read_ptr_triggered: extern struct {
            control: Mmio(ChannelControl, .rw),

            /// N.B. erratum RP2040-E12
            write_ptr: Mmio(*allowzero anyopaque, .rw),

            count: Mmio(u32, .rw),

            /// N.B. erratum RP2040-E12
            read_ptr: Mmio(*allowzero const anyopaque, .rw),
        },
    },
};

pub const DMA_DEBUG = [12]extern struct {
    /// write any value to reinitialize DREQ handshaking
    pending: Mmio(packed struct(u32) {
        count: u6 = 0,
        _reserved_6: u26 = 0,
    }, .rw),

    reload_count: Mmio(u32, .r),
    _reserved_8: [56]u8 = undefined,
};
