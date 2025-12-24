pub const Port_ID = enum {
    gpio,
    qspi,
};

pub const Port_Data_Type = u32;

pub const Config = struct {
    speed: ?io.Slew_Rate = null,
    hysteresis: ?bool = null,
    maintenance: ?io.Pin_Maintenance = null,
    strength: ?io.Drive_Strength = null,
    input_enabled: ?bool = null,
    output_disabled: ?bool = null,
};

pub fn get_port(comptime pad: Pad_ID) Port_ID {
    return if (@intFromEnum(pad) < 32) .gpio else .qspi;
}

pub const get_ports = defaults.gpio.get_ports;

pub fn get_offset(comptime pad: Pad_ID) comptime_int {
    const raw = @intFromEnum(pad);
    return if (raw < 32) raw else raw - 32;
}

pub const get_pads_in_port = defaults.gpio.get_pads_in_port;

pub fn configure(comptime pads: []const Pad_ID, config: Config) void {
    inline for (pads) |pad| {
        const n = @intFromEnum(pad);
        if (n < 30) {
            configure_internal(&peripherals.PADS.gpio[n], config);
        } else switch (pad) {
            .SWCLK => configure_internal(&peripherals.PADS.swclk, config),
            .SWDIO => configure_internal(&peripherals.PADS.swdio, config),
            .SCLK => configure_internal(&peripherals.PADS_QSPI.sclk, config),
            .SS => configure_internal(&peripherals.PADS_QSPI.ss, config),
            .SD0 => configure_internal(&peripherals.PADS_QSPI.sd[0], config),
            .SD1 => configure_internal(&peripherals.PADS_QSPI.sd[1], config),
            .SD2 => configure_internal(&peripherals.PADS_QSPI.sd[2], config),
            .SD3 => configure_internal(&peripherals.PADS_QSPI.sd[3], config),
            else => unreachable,
        }
    }
}

fn configure_internal(comptime pad: anytype, new_config: Config) void {
    var config = pad.read();
    if (new_config.speed) |s| config.speed = s;
    if (new_config.hysteresis) |h| config.hysteresis = h;
    if (new_config.maintenance) |m| config.maintenance = m;
    if (new_config.strength) |s| config.strength = s;
    if (new_config.input_enabled) |e| config.input_enabled = e;
    if (new_config.output_disabled) |d| config.output_disabled = d;
    pad.write(config);
}

pub fn ensure_init(comptime pads: []const Pad_ID) void {
    comptime var which: chip.reg_types.sys.Reset_Bitmap = .{};
    inline for (comptime get_ports(pads)) |port| {
        switch (port) {
            .gpio => {
                which.pads_bank0 = true;
                which.io_bank0 = true;
            },
            .qspi => {
                which.pads_qspi = true;
                which.io_qspi = true;
            },
        }
    }
    resets.ensure_not_in_reset(which);

    inline for (pads) |pad| {
        set_function(pad, .sio);
    }
}

pub fn set_functions(comptime pads: []const Pad_ID, comptime functions: anytype) void {
    inline for (pads, functions) |pad, function| {
        set_function(pad, function);
    }
}

pub fn set_function_all(comptime pads: []const Pad_ID, comptime function: anytype) void {
    inline for (pads) |pad| {
        set_function(pad, function);
    }
}

pub fn set_function(comptime pad: Pad_ID, comptime function: anytype) void {
    const n = @intFromEnum(pad);
    if (n < 30) {
        const func = comptime std.enums.nameCast(io.IO_Function, function);
        peripherals.IO[n].control.modify(.{ .func = func });
    } else {
        const func = comptime std.enums.nameCast(io.QSPI_Function, function);
        switch (pad) {
            .SCLK => peripherals.IO_QSPI.sclk.control.modify(.{ .func = func }),
            .SS  => peripherals.IO_QSPI.ss.control.modify(.{ .func = func }),
            .SD0 => peripherals.IO_QSPI.sd[0].control.modify(.{ .func = func }),
            .SD1 => peripherals.IO_QSPI.sd[1].control.modify(.{ .func = func }),
            .SD2 => peripherals.IO_QSPI.sd[2].control.modify(.{ .func = func }),
            .SD3 => peripherals.IO_QSPI.sd[3].control.modify(.{ .func = func }),
            else => @compileError("SWD pads don't have configurable functions"),
        }
    }
}

pub fn read_input_port(comptime port: Port_ID) Port_Data_Type {
    return switch (port) {
        .gpio => peripherals.SIO.io.in.read(),
        .qspi => peripherals.SIO.io.in_qspi.read(),
    };
}

pub fn read_output_port(comptime port: Port_ID) Port_Data_Type {
    return switch (port) {
        .gpio => peripherals.SIO.io.out.value.read(),
        .qspi => peripherals.SIO.io.out_qspi.value.read(),
    };
}

pub fn write_output_port(comptime port: Port_ID, state: Port_Data_Type) void {
    switch (port) {
        .gpio => peripherals.SIO.io.out.value.write(state),
        .qspi => peripherals.SIO.io.out_qspi.value.write(state),
    }
}

pub fn clear_output_port_bits(comptime port: Port_ID, bits_to_clear: Port_Data_Type) void {
    switch (port) {
        .gpio => peripherals.SIO.io.out.clear.write(bits_to_clear),
        .qspi => peripherals.SIO.io.out_qspi.clear.write(bits_to_clear),
    }
}

pub fn set_output_port_bits(comptime port: Port_ID, bits_to_set: Port_Data_Type) void {
    switch (port) {
        .gpio => peripherals.SIO.io.out.set.write(bits_to_set),
        .qspi => peripherals.SIO.io.out_qspi.set.write(bits_to_set),
    }
}

pub fn toggle_output_port_bits(comptime port: Port_ID, bits_to_toggle: Port_Data_Type) void {
    switch (port) {
        .gpio => peripherals.SIO.io.out.toggle.write(bits_to_toggle),
        .qspi => peripherals.SIO.io.out_qspi.toggle.write(bits_to_toggle),
    }
}

pub fn modify_output_port(comptime port: Port_ID, bits_to_clear: Port_Data_Type, bits_to_set: Port_Data_Type) void {
    switch (port) {
        .gpio => {
            const old = peripherals.SIO.io.out.value.read();
            var val = old;
            val |= bits_to_set;
            val &= ~bits_to_clear;
            peripherals.SIO.io.out.toggle.write(val ^ old);
        },
        .qspi => {
            const old = peripherals.SIO.io.out_qspi.value.read();
            var val = old;
            val |= bits_to_set;
            val &= ~bits_to_clear;
            peripherals.SIO.io.out_qspi.toggle.write(val ^ old);
        },
    }
}

pub fn read_output_port_enables(comptime port: Port_ID) Port_Data_Type {
    return switch (port) {
        .gpio => peripherals.SIO.io.oe.value.read(),
        .qspi => peripherals.SIO.io.oe_qspi.value.read(),
    };
}

pub fn write_output_port_enables(comptime port: Port_ID, state: Port_Data_Type) void {
    switch (port) {
        .gpio => peripherals.SIO.io.oe.value.write(state),
        .qspi => peripherals.SIO.io.oe_qspi.value.write(state),
    }
}

pub fn clear_output_port_enable_bits(comptime port: Port_ID, bits_to_clear: Port_Data_Type) void {
    switch (port) {
        .gpio => peripherals.SIO.io.oe.clear.write(bits_to_clear),
        .qspi => peripherals.SIO.io.oe_qspi.clear.write(bits_to_clear),
    }
}

pub fn set_output_port_enable_bits(comptime port: Port_ID, bits_to_set: Port_Data_Type) void {
    switch (port) {
        .gpio => peripherals.SIO.io.oe.set.write(bits_to_set),
        .qspi => peripherals.SIO.io.oe_qspi.set.write(bits_to_set),
    }
}

pub fn toggle_output_port_enable_bits(comptime port: Port_ID, bits_to_toggle: Port_Data_Type) void {
    switch (port) {
        .gpio => peripherals.SIO.io.oe.toggle.write(bits_to_toggle),
        .qspi => peripherals.SIO.io.oe_qspi.toggle.write(bits_to_toggle),
    }
}

pub fn modify_output_port_enables(comptime port: Port_ID, bits_to_clear: Port_Data_Type, bits_to_set: Port_Data_Type) void {
    switch (port) {
        .gpio => {
            const old = peripherals.SIO.io.oe.value.read();
            var val = old;
            val |= bits_to_set;
            val &= ~bits_to_clear;
            peripherals.SIO.io.oe.toggle.write(val ^ old);
        },
        .qspi => {
            const old = peripherals.SIO.io.oe_qspi.value.read();
            var val = old;
            val |= bits_to_set;
            val &= ~bits_to_clear;
            peripherals.SIO.io.oe_qspi.toggle.write(val ^ old);
        },
    }
}

pub const read_input = defaults.gpio.read_input;
pub const read_output = defaults.gpio.read_output;
pub const write_output = defaults.gpio.write_output;
pub const set_outputs = defaults.gpio.set_outputs;
pub const clear_outputs = defaults.gpio.clear_ouputs;
pub const toggle_outputs = defaults.gpio.toggle_outputs;
pub const read_output_enable = defaults.gpio.read_output_enable;
pub const write_output_enable = defaults.gpio.write_output_enable;
pub const set_output_enables = defaults.gpio.set_output_enables;
pub const clear_output_enables = defaults.gpio.clear_output_enables;
pub const toggle_output_enables = defaults.gpio.toggle_output_enables;

const resets = @import("resets.zig");
const peripherals = @import("peripherals.zig");
const Pad_ID = chip.Pad_ID;
const io = chip.reg_types.io;
const chip = @import("../rp2040.zig");
const defaults = @import("microbe_internal");
const std = @import("std");
