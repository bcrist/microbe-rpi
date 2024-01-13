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

pub fn get_ports(comptime pads: []const Pad_ID) []const Port_ID {
    comptime {
        var ports: [pads.len]Port_ID = undefined;
        var n = 0;
        outer: for (pads) |pad| {
            const port = get_port(pad);
            for (ports[0..n]) |p| {
                if (p == port) continue :outer;
            }
            ports[n] = port;
            n += 1;
        }
        return ports[0..n];
    }
}

pub fn get_offset(comptime pad: Pad_ID) comptime_int {
    const raw = @intFromEnum(pad);
    return if (raw < 32) raw else raw - 32;
}

pub fn get_pads_in_port(
    comptime pads: []const Pad_ID,
    comptime port: Port_ID,
    comptime min_offset: comptime_int,
    comptime max_offset: comptime_int,
) []const Pad_ID {
    comptime {
        var pads_in_port: []const Pad_ID = &.{};
        for (pads) |pad| {
            const pad_port = get_port(pad);
            const pad_offset = get_offset(pad);
            if (pad_port == port and pad_offset >= min_offset and pad_offset <= max_offset) {
                pads_in_port = pads_in_port ++ &[_]Pad_ID{pad};
            }
        }
        return pads_in_port;
    }
}

pub fn configure(comptime pads: []const Pad_ID, config: Config) void {
    inline for (pads) |pad| {
        const n = @intFromEnum(pad);
        if (n < 30) {
            configure_internal(&chip.PADS.gpio[n], config);
        } else switch (pad) {
            .SWCLK => configure_internal(&chip.PADS.swclk, config),
            .SWDIO => configure_internal(&chip.PADS.swdio, config),
            .SCLK => configure_internal(&chip.PADS_QSPI.sclk, config),
            .SS => configure_internal(&chip.PADS_QSPI.ss, config),
            .SD0 => configure_internal(&chip.PADS_QSPI.sd[0], config),
            .SD1 => configure_internal(&chip.PADS_QSPI.sd[1], config),
            .SD2 => configure_internal(&chip.PADS_QSPI.sd[2], config),
            .SD3 => configure_internal(&chip.PADS_QSPI.sd[3], config),
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
        chip.IO[n].control.modify(.{ .func = func });
    } else {
        const func = comptime std.enums.nameCast(io.QSPI_Function, function);
        switch (pad) {
            .SCLK => chip.IO_QSPI.sclk.control.modify(.{ .func = func }),
            .SS  => chip.IO_QSPI.ss.control.modify(.{ .func = func }),
            .SD0 => chip.IO_QSPI.sd[0].control.modify(.{ .func = func }),
            .SD1 => chip.IO_QSPI.sd[1].control.modify(.{ .func = func }),
            .SD2 => chip.IO_QSPI.sd[2].control.modify(.{ .func = func }),
            .SD3 => chip.IO_QSPI.sd[3].control.modify(.{ .func = func }),
            else => @compileError("SWD pads don't have configurable functions"),
        }
    }
}

pub fn read_input_port(comptime port: Port_ID) Port_Data_Type {
    return switch (port) {
        .gpio => chip.SIO.io.in.read(),
        .qspi => chip.SIO.io.in_qspi.read(),
    };
}

pub fn read_output_port(comptime port: Port_ID) Port_Data_Type {
    return switch (port) {
        .gpio => chip.SIO.io.out.value.read(),
        .qspi => chip.SIO.io.out_qspi.value.read(),
    };
}

pub fn write_output_port(comptime port: Port_ID, state: Port_Data_Type) void {
    switch (port) {
        .gpio => chip.SIO.io.out.value.write(state),
        .qspi => chip.SIO.io.out_qspi.value.write(state),
    }
}

pub fn clear_output_port_bits(comptime port: Port_ID, bits_to_clear: Port_Data_Type) void {
    switch (port) {
        .gpio => chip.SIO.io.out.clear.write(bits_to_clear),
        .qspi => chip.SIO.io.out_qspi.clear.write(bits_to_clear),
    }
}

pub fn set_output_port_bits(comptime port: Port_ID, bits_to_set: Port_Data_Type) void {
    switch (port) {
        .gpio => chip.SIO.io.out.set.write(bits_to_set),
        .qspi => chip.SIO.io.out_qspi.set.write(bits_to_set),
    }
}

pub fn toggle_output_port_bits(comptime port: Port_ID, bits_to_toggle: Port_Data_Type) void {
    switch (port) {
        .gpio => chip.SIO.io.out.toggle.write(bits_to_toggle),
        .qspi => chip.SIO.io.out_qspi.toggle.write(bits_to_toggle),
    }
}

pub fn modify_output_port(comptime port: Port_ID, bits_to_clear: Port_Data_Type, bits_to_set: Port_Data_Type) void {
    switch (port) {
        .gpio => {
            const old = chip.SIO.io.out.value.read();
            var val = old;
            val |= bits_to_set;
            val &= ~bits_to_clear;
            chip.SIO.io.out.toggle.write(val ^ old);
        },
        .qspi => {
            const old = chip.SIO.io.out_qspi.value.read();
            var val = old;
            val |= bits_to_set;
            val &= ~bits_to_clear;
            chip.SIO.io.out_qspi.toggle.write(val ^ old);
        },
    }
}

pub fn read_output_port_enables(comptime port: Port_ID) Port_Data_Type {
    return switch (port) {
        .gpio => chip.SIO.io.oe.value.read(),
        .qspi => chip.SIO.io.oe_qspi.value.read(),
    };
}

pub fn write_output_port_enables(comptime port: Port_ID, state: Port_Data_Type) void {
    switch (port) {
        .gpio => chip.SIO.io.oe.value.write(state),
        .qspi => chip.SIO.io.oe_qspi.value.write(state),
    }
}

pub fn clear_output_port_enable_bits(comptime port: Port_ID, bits_to_clear: Port_Data_Type) void {
    switch (port) {
        .gpio => chip.SIO.io.oe.clear.write(bits_to_clear),
        .qspi => chip.SIO.io.oe_qspi.clear.write(bits_to_clear),
    }
}

pub fn set_output_port_enable_bits(comptime port: Port_ID, bits_to_set: Port_Data_Type) void {
    switch (port) {
        .gpio => chip.SIO.io.oe.set.write(bits_to_set),
        .qspi => chip.SIO.io.oe_qspi.set.write(bits_to_set),
    }
}

pub fn toggle_output_port_enable_bits(comptime port: Port_ID, bits_to_toggle: Port_Data_Type) void {
    switch (port) {
        .gpio => chip.SIO.io.oe.toggle.write(bits_to_toggle),
        .qspi => chip.SIO.io.oe_qspi.toggle.write(bits_to_toggle),
    }
}

pub fn modify_output_port_enables(comptime port: Port_ID, bits_to_clear: Port_Data_Type, bits_to_set: Port_Data_Type) void {
    switch (port) {
        .gpio => {
            const old = chip.SIO.io.oe.value.read();
            var val = old;
            val |= bits_to_set;
            val &= ~bits_to_clear;
            chip.SIO.io.oe.toggle.write(val ^ old);
        },
        .qspi => {
            const old = chip.SIO.io.oe_qspi.value.read();
            var val = old;
            val |= bits_to_set;
            val &= ~bits_to_clear;
            chip.SIO.io.oe_qspi.toggle.write(val ^ old);
        },
    }
}

pub inline fn read_input(comptime pad: Pad_ID) u1 {
    const offset = comptime get_offset(pad);
    return @truncate(read_input_port(comptime get_port(pad)) >> offset);
}

pub inline fn read_output(comptime pad: Pad_ID) u1 {
    const offset = comptime get_offset(pad);
    return @truncate(read_output_port(comptime get_port(pad)) >> offset);
}

pub inline fn write_output(comptime pad: Pad_ID, state: u1) void {
    const port = comptime get_port(pad);
    const mask = @as(Port_Data_Type, 1) << comptime get_offset(pad);
    if (state == 0) {
        clear_output_port_bits(port, mask);
    } else {
        set_output_port_bits(port, mask);
    }
}

pub inline fn set_outputs(comptime pads: []const Pad_ID) void {
    inline for (comptime get_ports(pads)) |port| {
        var mask: Port_Data_Type = 0;
        inline for (pads) |pad| {
            if (comptime get_port(pad) == port) {
                mask |= @as(Port_Data_Type, 1) << comptime chip.gpio.get_offset(pad);
            }
        }
        set_output_port_bits(port, mask);
    }
}
pub inline fn clear_outputs(comptime pads: []const Pad_ID) void {
    inline for (comptime get_ports(pads)) |port| {
        var mask: Port_Data_Type = 0;
        inline for (pads) |pad| {
            if (comptime get_port(pad) == port) {
                mask |= @as(Port_Data_Type, 1) << comptime chip.gpio.get_offset(pad);
            }
        }
        clear_output_port_bits(port, mask);
    }
}
pub inline fn toggle_outputs(comptime pads: []const Pad_ID) void {
    inline for (comptime get_ports(pads)) |port| {
        var mask: Port_Data_Type = 0;
        inline for (pads) |pad| {
            if (comptime get_port(pad) == port) {
                mask |= @as(Port_Data_Type, 1) << comptime chip.gpio.get_offset(pad);
            }
        }
        toggle_output_port_bits(port, mask);
    }
}

pub inline fn read_output_enable(comptime pad: Pad_ID) u1 {
    const offset = comptime get_offset(pad);
    return @truncate(read_output_port_enables(comptime get_port(pad)) >> offset);
}

pub inline fn write_output_enable(comptime pad: Pad_ID, state: u1) void {
    const port = comptime get_port(pad);
    const mask = @as(Port_Data_Type, 1) << comptime get_offset(pad);
    if (state == 0) {
        clear_output_port_enable_bits(port, mask);
    } else {
        set_output_port_enable_bits(port, mask);
    }
}

pub inline fn set_output_enables(comptime pads: []const Pad_ID) void {
    inline for (comptime get_ports(pads)) |port| {
        var mask: Port_Data_Type = 0;
        inline for (pads) |pad| {
            if (comptime get_port(pad) == port) {
                mask |= @as(Port_Data_Type, 1) << comptime chip.gpio.get_offset(pad);
            }
        }
        set_output_port_enable_bits(port, mask);
    }
}
pub inline fn clear_output_enables(comptime pads: []const Pad_ID) void {
    inline for (comptime get_ports(pads)) |port| {
        var mask: Port_Data_Type = 0;
        inline for (pads) |pad| {
            if (comptime get_port(pad) == port) {
                mask |= @as(Port_Data_Type, 1) << comptime chip.gpio.get_offset(pad);
            }
        }
        clear_output_port_enable_bits(port, mask);
    }
}
pub inline fn toggle_output_enables(comptime pads: []const Pad_ID) void {
    inline for (comptime get_ports(pads)) |port| {
        var mask: Port_Data_Type = 0;
        inline for (pads) |pad| {
            if (comptime get_port(pad) == port) {
                mask |= @as(Port_Data_Type, 1) << comptime chip.gpio.get_offset(pad);
            }
        }
        toggle_output_port_enable_bits(port, mask);
    }
}

const resets = @import("resets.zig");
const Pad_ID = chip.Pad_ID;
const io = chip.reg_types.io;
const chip = @import("chip");
const std = @import("std");
