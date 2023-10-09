const std = @import("std");
const chip = @import("chip");
const io = chip.reg_types.io;

const PadID = chip.PadID;

pub const PortID = enum {
    gpio,
    qspi,
};

pub const PortDataType = u32;

pub fn getPort(comptime pad: PadID) PortID {
    return if (@intFromEnum(pad) < 32) .gpio else .qspi;
}

pub fn getPorts(comptime pads: []const PadID) []const PortID {
    comptime {
        var ports: [pads.len]PortID = undefined;
        var n = 0;
        outer: inline for (pads) |pad| {
            const port = getPort(pad);
            inline for (ports[0..n]) |p| {
                if (p == port) continue :outer;
            }
            ports[n] = port;
            n += 1;
        }
        return ports[0..n];
    }
}

pub fn getOffset(comptime pad: PadID) comptime_int {
    const raw = @intFromEnum(pad);
    return if (raw < 32) raw else raw - 32;
}

pub fn getPadsInPort(
    comptime pads: []const PadID,
    comptime port: PortID,
    comptime min_offset: comptime_int,
    comptime max_offset: comptime_int,
) []const PadID {
    comptime {
        var pads_in_port: []const PadID = &.{};
        inline for (pads) |pad| {
            const pad_port = getPort(pad);
            const pad_offset = getOffset(pad);
            if (pad_port == port and pad_offset >= min_offset and pad_offset <= max_offset) {
                pads_in_port = pads_in_port ++ &[_]PadID{pad};
            }
        }
        return pads_in_port;
    }
}

pub const Config = struct {
    speed: ?io.SlewRate = null,
    hysteresis: ?bool = null,
    maintenance: ?io.PinMaintenance = null,
    strength: ?io.DriveStrength = null,
    input_enabled: ?bool = null,
    output_disabled: ?bool = null,
};

pub fn configure(comptime pads: []const PadID, config: Config) void {
    inline for (pads) |pad| {
        const n = @intFromEnum(pad);
        if (n < 30) {
            configureInternal(&chip.PADS.gpio[n], config);
        } else switch (pad) {
            .SWCLK => configureInternal(&chip.PADS.swclk, config),
            .SWDIO => configureInternal(&chip.PADS.swdio, config),
            .SCLK => configureInternal(&chip.PADS_QSPI.sclk, config),
            .SS => configureInternal(&chip.PADS_QSPI.ss, config),
            .SD0 => configureInternal(&chip.PADS_QSPI.sd[0], config),
            .SD1 => configureInternal(&chip.PADS_QSPI.sd[1], config),
            .SD2 => configureInternal(&chip.PADS_QSPI.sd[2], config),
            .SD3 => configureInternal(&chip.PADS_QSPI.sd[3], config),
            else => unreachable,
        }
    }
}

fn configureInternal(comptime pad: anytype, new_config: Config) void {
    var config = pad.read();
    if (new_config.speed) |s| config.speed = s;
    if (new_config.hysteresis) |h| config.hysteresis = h;
    if (new_config.maintenance) |m| config.maintenance = m;
    if (new_config.strength) |s| config.strength = s;
    if (new_config.input_enabled) |e| config.input_enabled = e;
    if (new_config.output_disabled) |d| config.output_disabled = d;
    pad.write(config);
}

pub fn ensureInit(comptime pads: []const PadID) void {
    var resets = chip.RESETS.force.read();
    inline for (comptime getPorts(pads)) |port| {
        switch (port) {
            .gpio => {
                resets.pads_bank0 = false;
                resets.io_bank0 = false;
            },
            .qspi => {
                resets.pads_qspi = false;
                resets.io_qspi = false;
            },
        }
    }
    chip.RESETS.force.write(resets);

    inline for (pads) |pad| {
        setFunction(pad, .sio);
    }
}

pub fn setFunctions(comptime pads: []const PadID, comptime functions: anytype) void {
    inline for (pads, functions) |pad, function| {
        setFunction(pad, function);
    }
}

pub fn setFunctionAll(comptime pads: []const PadID, comptime function: anytype) void {
    inline for (pads) |pad| {
        setFunction(pad, function);
    }
}

pub fn setFunction(comptime pad: PadID, comptime function: anytype) void {
    const n = @intFromEnum(pad);
    if (n < 30) {
        const func = std.enums.nameCast(io.IoFunction, function);
        chip.IO[n].control.modify(.{ .func = func });
    } else {
        const func = std.enums.nameCast(io.QspiFunction, function);
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

pub fn readInputPort(comptime port: PortID) PortDataType {
    return switch (port) {
        .gpio => chip.SIO.io.in.read(),
        .qspi => chip.SIO.io.in_qspi.read(),
    };
}

pub fn readOutputPort(comptime port: PortID) PortDataType {
    return switch (port) {
        .gpio => chip.SIO.io.out.value.read(),
        .qspi => chip.SIO.io.out_qspi.value.read(),
    };
}

pub fn writeOutputPort(comptime port: PortID, state: PortDataType) void {
    switch (port) {
        .gpio => chip.SIO.io.out.value.write(state),
        .qspi => chip.SIO.io.out_qspi.value.write(state),
    }
}

pub fn clearOutputPortBits(comptime port: PortID, bits_to_clear: PortDataType) void {
    switch (port) {
        .gpio => chip.SIO.io.out.clear.write(bits_to_clear),
        .qspi => chip.SIO.io.out_qspi.clear.write(bits_to_clear),
    }
}

pub fn setOutputPortBits(comptime port: PortID, bits_to_set: PortDataType) void {
    switch (port) {
        .gpio => chip.SIO.io.out.set.write(bits_to_set),
        .qspi => chip.SIO.io.out_qspi.set.write(bits_to_set),
    }
}

pub fn modifyOutputPort(comptime port: PortID, bits_to_clear: PortDataType, bits_to_set: PortDataType) void {
    switch (port) {
        .gpio => {
            chip.SIO.io.out.clear.write(bits_to_clear);
            chip.SIO.io.out.set.write(bits_to_set);
        },
        .qspi => {
            chip.SIO.io.out_qspi.clear.write(bits_to_clear);
            chip.SIO.io.out_qspi.set.write(bits_to_set);
        },
    }
}

pub fn readOutputPortEnables(comptime port: PortID) PortDataType {
    return switch (port) {
        .gpio => chip.SIO.io.oe.value.read(),
        .qspi => chip.SIO.io.oe_qspi.value.read(),
    };
}

pub fn writeOutputPortEnables(comptime port: PortID, state: PortDataType) void {
    switch (port) {
        .gpio => chip.SIO.io.oe.value.write(state),
        .qspi => chip.SIO.io.oe_qspi.value.write(state),
    }
}

pub fn clearOutputPortEnableBits(comptime port: PortID, bits_to_clear: PortDataType) void {
    switch (port) {
        .gpio => chip.SIO.io.oe.clear.write(bits_to_clear),
        .qspi => chip.SIO.io.oe_qspi.clear.write(bits_to_clear),
    }
}

pub fn setOutputPortEnableBits(comptime port: PortID, bits_to_set: PortDataType) void {
    switch (port) {
        .gpio => chip.SIO.io.oe.set.write(bits_to_set),
        .qspi => chip.SIO.io.oe_qspi.set.write(bits_to_set),
    }
}

pub fn modifyOutputPortEnables(comptime port: PortID, bits_to_clear: PortDataType, bits_to_set: PortDataType) void {
    switch (port) {
        .gpio => {
            chip.SIO.io.oe.clear.write(bits_to_clear);
            chip.SIO.io.oe.set.write(bits_to_set);
        },
        .qspi => {
            chip.SIO.io.oe_qspi.clear.write(bits_to_clear);
            chip.SIO.io.oe_qspi.set.write(bits_to_set);
        },
    }
}

pub inline fn readInput(comptime pad: PadID) u1 {
    const offset = comptime getOffset(pad);
    return @truncate(readInputPort(comptime getPort(pad)) >> offset);
}

pub inline fn readOutput(comptime pad: PadID) u1 {
    const offset = comptime getOffset(pad);
    return @truncate(readOutputPort(comptime getPort(pad)) >> offset);
}

pub inline fn writeOutput(comptime pad: PadID, state: u1) void {
    const port = comptime getPort(pad);
    const mask = @as(PortDataType, 1) << comptime getOffset(pad);
    if (state == 0) {
        clearOutputPortBits(port, mask);
    } else {
        setOutputPortBits(port, mask);
    }
}

pub inline fn readOutputEnable(comptime pad: PadID) u1 {
    const offset = comptime getOffset(pad);
    return @truncate(readOutputPortEnables(comptime getPort(pad)) >> offset);
}

pub inline fn writeOutputEnable(comptime pad: PadID, state: u1) void {
    const port = comptime getPort(pad);
    const mask = @as(PortDataType, 1) << comptime getOffset(pad);
    if (state == 0) {
        clearOutputPortEnableBits(port, mask);
    } else {
        setOutputPortEnableBits(port, mask);
    }
}

pub inline fn setOutputEnables(comptime pads: []const PadID) void {
    inline for (comptime getPorts(pads)) |port| {
        var mask: PortDataType = 0;
        inline for (pads) |pad| {
            if (comptime getPort(pad) == port) {
                mask |= @as(PortDataType, 1) << comptime chip.gpio.getOffset(pad);
            }
        }
        setOutputPortEnableBits(port, mask);
    }
}
pub inline fn clearOutputEnables(comptime pads: []const PadID) void {
    inline for (comptime getPorts(pads)) |port| {
        var mask: PortDataType = 0;
        inline for (pads) |pad| {
            if (comptime getPort(pad) == port) {
                mask |= @as(PortDataType, 1) << comptime chip.gpio.getOffset(pad);
            }
        }
        clearOutputPortEnableBits(port, mask);
    }
}
