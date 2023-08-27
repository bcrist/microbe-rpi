/// Adapted from
/// https://github.com/raspberrypi/pico-sdk/blob/master/src/rp2_common/boot_stage2/boot2_w25q080.S

const std = @import("std");
const chip = @import("chip");
const config = @import("config");

const flash_clock_div = config.flash_clock_div;
comptime {
    if (flash_clock_div == 0) @compileError("flash_clock_div must be >= 2");
    if ((flash_clock_div & 1) != 0) @compileError("flash_clock_div must be even");
}

// Note ZD25Q only requires bit 4 and bit 5 to be different.
const continuous_read_mode_bits: u8 = 0xA0;

const Command = enum(u8) {
    write_enable_volatile_status_reg = 0x50,
    read_status_reg_0 = 0x05,
    read_status_reg_1 = 0x35,
    write_status_reg_1 = 0x31,
    quad_read = 0xEB,
};

const StatusRegister0 = packed struct(u8) {
    write_in_progress: bool,
    write_enable: bool,
    block_protect_0: bool,
    block_protect_1: bool,
    block_protect_2: bool,
    block_protect_3: bool,
    block_protect_4: bool,
    status_register_protect_0: u1,
};

const StatusRegister1 = packed struct(u8) {
    status_register_protect_1: u1,
    quad_enable: bool,
    erase_suspend_flag: bool,
    security_register_protect_0: bool,
    security_register_protect_1: bool,
    security_register_protect_2: bool,
    block_protect_mode: bool,
    program_suspend_flag: bool,
};

extern fn _boot3() callconv(.Naked) noreturn;
export fn _boot2() linksection(".boot2_entry") callconv(.Naked) noreturn {
    asm volatile ("blx %[func]" :: [func] "r" (&setupXip) : "memory");
    asm volatile ("bx %[func]" :: [func] "r" (&_boot3));
    unreachable;
}

fn setupXip() linksection(".boot2") callconv (.C) void {
    chip.PADS_QSPI.GPIO_QSPI_SCLK.write(.{
        .speed = .fast,
        .strength = .@"8mA",
        .input_enabled = false,
    });

    chip.PADS_QSPI.GPIO_QSPI_SD0.write(.{
        .speed = .fast,
        .hysteresis = false,
    });
    chip.PADS_QSPI.GPIO_QSPI_SD1.write(.{
        .speed = .fast,
        .hysteresis = false,
    });
    chip.PADS_QSPI.GPIO_QSPI_SD2.write(.{
        .speed = .fast,
        .hysteresis = false,
    });
    chip.PADS_QSPI.GPIO_QSPI_SD3.write(.{
        .speed = .fast,
        .hysteresis = false,
    });

    chip.SSI.enable.write(.{ .enable = false });
    chip.SSI.baud_rate.write(.{ .clock_divisor = flash_clock_div });

    // Set 1-cycle sample delay. If flash_clock_div == 2 then this means,
    // if the flash launches data on SCLK posedge, we capture it at the time that
    // the next SCLK posedge is launched. This is shortly before that posedge
    // arrives at the flash, so data hold time should be ok. For
    // flash_clock_div > 2 this pretty much has no effect.
    chip.SSI.rx_sample_delay.write(.{ .delay = 1 });

    chip.SSI.control_0.write(.{
        .frame_format = .spi,
        .spi_frame_format = .standard,
        .transfer_mode = .tx_and_rx,
        .data_frame_size = ._8_bits,
    });

    chip.SSI.enable.write(.{ .enable = true });
    defer chip.SSI.enable.write(.{ .enable = false });

    var sr1 = doReadCommand(.read_status_reg_1, StatusRegister1);
    if (!sr1.quad_enable) {
        sr1.quad_enable = true;

        doWriteCommand(.write_enable_volatile_status_reg, void, {});
        doWriteCommand(.write_status_reg_1, StatusRegister1, sr1);

        while (doReadCommand(.read_status_reg_0, StatusRegister0).write_in_progress) {}
    }

    chip.SSI.control_0.write(.{
        .frame_format = .spi,
        .spi_frame_format = .quad,
        .transfer_mode = .eeprom_read,
        .data_frame_size = ._32_bits,
    });

    chip.SSI.control_1.write(.{
        .num_data_frames = 0, // single 32b read
    });

    chip.SSI.spi_control.write(.{
        .transfer_format = .standard_command_wide_address,
        .command_length = ._8_bits,
        .address_length = ._32_bits,
        .wait_cycles_after_mode = 4,
    });

    chip.SSI.enable.write(.{ .enable = true });

    chip.SSI.data[0].write(@intFromEnum(Command.quad_read));
    chip.SSI.data[0].write(continuous_read_mode_bits); // upper 24 bits are address; we don't actually care what they are.
    blockUntilTxComplete();

    chip.SSI.enable.write(.{ .enable = false });

    chip.SSI.spi_control.write(.{
        .transfer_format = .wide_command_wide_address,
        .command_length = .none,
        .address_length = ._32_bits,
        .wait_cycles_after_mode = 4,
        .xip_command_or_mode = continuous_read_mode_bits,
    });

    chip.SSI.enable.write(.{ .enable = true });
}

fn blockUntilTxComplete() linksection(".boot2") void {
    var status = chip.SSI.status.read();
    while (!status.tx_fifo_empty or status.busy) {
        status = chip.SSI.status.read();
    }
}

fn doWriteCommand(command: Command, comptime T: type, value: T) linksection(".boot2") void {
    if (@sizeOf(T) == 0) {
        chip.SSI.data[0].write(@intFromEnum(command));
        blockUntilTxComplete();
        _ = chip.SSI.data[0].read();
    } else {
        const Raw = std.meta.Int(.unsigned, @bitSizeOf(T));
        var raw: Raw = @bitCast(value);

        chip.SSI.data[0].write(@intFromEnum(command));
        inline for (0..@sizeOf(T)) |byte_index| {
            const b: u8 = @truncate(raw >> @intCast(byte_index * 8));
            chip.SSI.data[0].write(b);
        }

        blockUntilTxComplete();

        _ = chip.SSI.data[0].read();
        inline for (0..@sizeOf(T)) |_| {
            _ = chip.SSI.data[0].read();
        }
    }
}

fn doReadCommand(command: Command, comptime T: type) linksection(".boot2") T {
    const Raw = std.meta.Int(.unsigned, @bitSizeOf(T));

    chip.SSI.data[0].write(@intFromEnum(command));
    inline for (0..@sizeOf(T)) |_| {
        chip.SSI.data[0].write(0);
    }

    blockUntilTxComplete();

    _ = chip.SSI.data[0].read();
    var raw: Raw = 0;
    inline for (0..@sizeOf(T)) |byte_index| {
        const b: Raw = @truncate(chip.SSI.data[0].read());
        raw |= b << @intCast(byte_index * 8);
    }

    return @bitCast(raw);
}

pub fn main() void {}
