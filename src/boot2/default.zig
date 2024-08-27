/// This should work for most 25xxx QSPI flash devices, where:
///    * The device supports the read status register (SR) command (0x05).
///    * The device supports either the write enable command (0x06) or volatile SR write enable (0x50).
///    * Bit 0 of the SR is the "write in progress" flag.
///    * There is a "quad enable" (QE) bit somewhere in the SR.
///    * The device supports the write status register command (0x01).
///        * Alternatively the write status register 1 command (0x31) can be used instead,
///          if QE is in the upper byte and the device supports it.
///    * The device supports the quad fast read command (0xEB).
///        * Using 24 address bits + 8 mode bits + N dummy cycles before data transfer.

const flash_clock_div = config.flash_clock_div;
comptime {
    if (flash_clock_div == 0) @compileError("flash_clock_div must be >= 2");
    if ((flash_clock_div & 1) != 0) @compileError("flash_clock_div must be even");
}

const Command = enum(u8) {
    write_disable = 0x04,
    write_enable = 0x06,
    write_enable_volatile_status_reg = 0x50,
    read_status_reg_0 = 0x05,
    read_status_reg_1 = 0x35,
    write_status_reg = 0x01,
    write_status_reg_1 = 0x31,
    quad_read = 0xEB,
};

const Status_Register_0 = if (config.flash_quad_enable_bit < 8) packed struct (u8) {
    write_in_progress: bool,
    _unused0: std.meta.Int(.unsigned, config.flash_quad_enable_bit - 1),
    quad_enable: bool,
    _unused1: std.meta.Int(.unsigned, 7 - config.flash_quad_enable_bit),
} else packed struct (u8) {
    write_in_progress: bool,
    _unused1: u7,
};

const Status_Register_1 = if (config.flash_quad_enable_bit < 8) u8 else packed struct (u8) {
    _unused0: std.meta.Int(.unsigned, config.flash_quad_enable_bit - 8),
    quad_enable: bool,
    _unused1: std.meta.Int(.unsigned, 15 - config.flash_quad_enable_bit),
};

const Full_Status_Register = packed struct (u16) {
    sr0: Status_Register_0,
    sr1: Status_Register_1,
};

extern fn _boot3() callconv(.C) void; // should actually be noreturn, but since we're not defining it here, we don't want to assume...
export fn _boot2() linksection(".boot2_entry") noreturn {
    setup_xip();
    _boot3();

    // should be unreachable, but in case _boot3 returns, we should lock up rather than going into UB
    while (true) asm volatile ("nop" ::: "memory");
}

fn setup_xip() void {
    peripherals.SSI.enable.write(.{ .enable = false });
    peripherals.SSI.baud_rate.write(.{ .clock_divisor = flash_clock_div });

    // Set 1-cycle sample delay. If flash_clock_div == 2 then this means,
    // if the flash launches data on SCLK posedge, we capture it at the time that
    // the next SCLK posedge is launched. This is shortly before that posedge
    // arrives at the flash, so data hold time should be ok. For
    // flash_clock_div > 2 this pretty much has no effect.
    peripherals.SSI.rx_sample_delay.write(.{ .delay = 1 });

    peripherals.SSI.control_0.write(.{
        .frame_format = .spi,
        .spi_frame_format = .standard,
        .transfer_mode = .tx_and_rx,
        .data_frame_size = ._8_bits,
    });

    peripherals.SSI.enable.write(.{ .enable = true });

    if (comptime config.flash_has_volatile_status_reg) {
        var sr0 = do_read_command(.read_status_reg_0, Status_Register_0);
        var sr1 = do_read_command(.read_status_reg_1, Status_Register_1);
        if (comptime config.flash_quad_enable_bit < 8) {
            sr0.quad_enable = true;
        } else {
            sr1.quad_enable = true;
        }
        // N.B. Command 50h only works with 01h on some devices, not 31h
        do_write_command(.write_enable_volatile_status_reg, void, {});
        do_write_command(.write_status_reg, Full_Status_Register, .{
            .sr0 = sr0,
            .sr1 = sr1,
        });
    } else if (comptime config.flash_quad_enable_bit < 8) {
        var sr0 = do_read_command(.read_status_reg_0, Status_Register_0);
        if (!sr0.quad_enable) {
            sr0.quad_enable = true;
            do_write_command(.write_enable, void, {});
            do_write_command(.write_status_reg, Status_Register_0, sr0);
            while (do_read_command(.read_status_reg_0, Status_Register_0).write_in_progress) {}
        }
    } else {
        var sr1 = do_read_command(.read_status_reg_1, Status_Register_1);
        if (!sr1.quad_enable) {
            sr1.quad_enable = true;

            do_write_command(.write_enable, void, {});
            if (comptime config.flash_has_write_status_reg_1) {
                do_write_command(.write_status_reg_1, Status_Register_1, sr1);
            } else {
                const sr0 = do_read_command(.read_status_reg_0, Status_Register_0);
                do_write_command(.write_status_reg, Full_Status_Register, .{
                    .sr0 = sr0,
                    .sr1 = sr1,
                });
            }

            while (do_read_command(.read_status_reg_0, Status_Register_0).write_in_progress) {}
        }
    }

    peripherals.SSI.enable.write(.{ .enable = false });

    peripherals.SSI.control_0.write(.{
        .frame_format = .spi,
        .spi_frame_format = .quad,
        .transfer_mode = .eeprom_read,
        .data_frame_size = ._32_bits,
    });

    peripherals.SSI.control_1.write(.{
        .num_data_frames = 0, // single 32b read
    });

    peripherals.SSI.spi_control.write(.{
        .transfer_format = .standard_command_wide_address,
        .command_length = ._8_bits,
        .address_length = ._32_bits,
        .wait_cycles_after_mode = config.xip_wait_cycles,
        .xip_command_or_mode = 0,
    });

    peripherals.SSI.enable.write(.{ .enable = true });

    peripherals.SSI.data[0].write(@intFromEnum(Command.quad_read));
    peripherals.SSI.data[0].write(config.xip_mode_bits); // upper 24 bits are address; we don't actually care what they are.
    block_until_tx_complete();

    peripherals.SSI.enable.write(.{ .enable = false });

    peripherals.SSI.spi_control.write(.{
        .transfer_format = .wide_command_wide_address,
        .command_length = .none,
        .address_length = ._32_bits,
        .wait_cycles_after_mode = config.xip_wait_cycles,
        .xip_command_or_mode = config.xip_mode_bits,
    });

    peripherals.SSI.enable.write(.{ .enable = true });
}

fn block_until_tx_complete() linksection(".boot2") void {
    var status = peripherals.SSI.status.read();
    while (!status.tx_fifo_empty or status.busy) {
        status = peripherals.SSI.status.read();
    }
}

fn do_write_command(command: Command, comptime T: type, value: T) linksection(".boot2") void {
    if (T == void) {
        do_write_command_uint(command, void, {});
    } else {
        const Raw = std.meta.Int(.unsigned, @bitSizeOf(T));
        do_write_command_uint(command, Raw, @bitCast(value));
    }
}

fn do_write_command_uint(command: Command, comptime Raw: type, value: Raw) linksection(".boot2") void {
    if (@sizeOf(Raw) == 0) {
        peripherals.SSI.data[0].write(@intFromEnum(command));
        block_until_tx_complete();
        _ = peripherals.SSI.data[0].read();
    } else {
        peripherals.SSI.data[0].write(@intFromEnum(command));
        inline for (0..@sizeOf(Raw)) |byte_index| {
            const b: u8 = @truncate(value >> @intCast(byte_index * 8));
            peripherals.SSI.data[0].write(b);
        }

        block_until_tx_complete();

        _ = peripherals.SSI.data[0].read();
        inline for (0..@sizeOf(Raw)) |_| {
            _ = peripherals.SSI.data[0].read();
        }
    }
}

fn do_read_command(command: Command, comptime T: type) linksection(".boot2") T {
    const Raw = std.meta.Int(.unsigned, @bitSizeOf(T));
    return @bitCast(do_read_command_uint(command, Raw));
}

fn do_read_command_uint(command: Command, comptime Raw: type) linksection(".boot2") Raw {
    peripherals.SSI.data[0].write(@intFromEnum(command));
    inline for (0..@sizeOf(Raw)) |_| {
        peripherals.SSI.data[0].write(0);
    }

    block_until_tx_complete();

    _ = peripherals.SSI.data[0].read();
    var raw: Raw = 0;
    inline for (0..@sizeOf(Raw)) |byte_index| {
        const b: Raw = @truncate(peripherals.SSI.data[0].read());
        raw |= b << @intCast(byte_index * 8);
    }

    return raw;
}

pub fn main() void {}

const config = @import("config");
const peripherals = chip.peripherals;
const chip = @import("chip");
const std = @import("std");
