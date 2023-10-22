const std = @import("std");
const reg_types = @import("reg_types.zig");
const peripherals = @import("peripherals.zig");
const clocks = @import("clocks.zig");
const resets = @import("resets.zig");
const microbe = @import("microbe");
const chip = @import("chip");
const Events = microbe.usb.Events;
const SetupPacket = microbe.usb.SetupPacket;
const PID = microbe.usb.PID;
const descriptor = microbe.usb.descriptor;
const endpoint = microbe.usb.endpoint;
const Mmio = microbe.Mmio;

const log = std.log.scoped(.usb);

comptime {
    // The clock config parser will check to make sure the frequency is close enough to 48MHz,
    // we just want to verify that it's enabled at all:
    if (clocks.getConfig().usb.frequency_hz == 0) {
        @compileError("USB frequency should be set to 48 MHz");
    }
}

pub const max_packet_size_bytes = 64;

var stalled_or_waiting: u32 = 0;

pub fn init() void {
    resets.reset(.usbctrl);

    handleBusReset();

    peripherals.USB_DEV.muxing.write(.{
        .to_phy = true,
        .software_control = true,
    });

    peripherals.USB_DEV.control.write(.{ .enabled = true, .mode = .device });
    peripherals.USB_DEV.power.write(.{ .vbus_detect = .{ .override_value = true }});
    peripherals.USB_DEV.power.write(.{ .vbus_detect = .{ .override_value = true, .override_enabled = true }});

    // Note that we're not actually enabling NVIC's USBCTRL_IRQ since we just check these from the main loop:
    peripherals.USB_DEV.interrupts.enable.write(.{
        .bus_reset = true,
        .setup_request = true,
        .buffer_transfer_complete = true,
        .connection_state = true,
        .suspend_state = true,
    });

    peripherals.USB_DEV.sie_control.write(.{
        .enable_pullups = true,
        .ep0_enable_buffer_interrupt = true,
        // .ep0_enable_interrupt_on_stall = true,
        // .ep0_enable_interrupt_on_nak = true,
    });
}

pub fn deinit() void {
    resets.holdInReset(.usbctrl);
}

pub fn handleBusReset() void {
    stalled_or_waiting = 0;
    for (0..16) |ep| {
        getBufferControl0(.{ .ep = @intCast(ep), .dir = .in }).write(.{});
    }
    peripherals.USB_DEV.buffer_transfer_complete.raw = ~@as(u32, 0);
    peripherals.USB_DEV.sie_status.clearBits(.bus_reset_detected);
    peripherals.USB_DEV.address.write(0);
}

pub fn pollEvents() Events {
    const s: reg_types.usb.DeviceInterruptBitmap = peripherals.USB_DEV.interrupts.status.read();
    const sie_status = peripherals.USB_DEV.sie_status.read();
    peripherals.USB_DEV.sie_status.write(.{
        .data_sequence_error_detected = true,
        .ack_received = true,
        .rx_overflow_error_detected = true,
        .bit_stuffing_error_detected = true,
        .crc_mismatch_detected = true,
        .connected = true,
        .suspended = true,
        .setup_packet_received = true,
    });

    if (s.connection_state) {
        if (sie_status.connected) {
            log.info("connected", .{});
        } else {
            log.info("disconnected", .{});
        }
    }

    if (s.suspend_state) {
        if (sie_status.suspended) {
            log.info("suspended", .{});
        } else {
            log.info("resumed", .{});
        }
    }

    if (sie_status.ack_received) log.debug("ack received", .{});
    if (sie_status.data_sequence_error_detected) log.warn("data sequence error", .{});
    if (sie_status.ack_timeout_detected) log.warn("ack timeout", .{});
    if (sie_status.rx_overflow_error_detected) log.warn("rx overflow", .{});
    if (sie_status.bit_stuffing_error_detected) log.warn("bit suffing error", .{});
    if (sie_status.crc_mismatch_detected) log.warn("CRC mismatch", .{});

    const stall_nak = peripherals.USB_DEV.stall_nak_interrupt_status.read();
    if (stall_nak.ep0.in) {
        log.debug("ep0 in stall/nak", .{});
        peripherals.USB_DEV.stall_nak_interrupt_status.write(.{ .ep0 = .{ .in = true }});
    }

    if (stall_nak.ep0.out) {
        log.debug("ep0 out stall/nak", .{});
        peripherals.USB_DEV.stall_nak_interrupt_status.write(.{ .ep0 = .{ .out = true }});
    }

    if (s.setup_request) {
        peripherals.USB_DEV.ep_abort.setBits(.{ .ep0 = .{ .in = true, .out = true }});
        if (peripherals.USB_BUF.buffer_control.ep0.device.in0.read().transfer_pending) {
            while (!peripherals.USB_DEV.ep_abort_complete.read().ep0.in) {}
            peripherals.USB_BUF.buffer_control.ep0.device.in0.write(.{});
            log.debug("ep0 in aborted", .{});
        }

        if (peripherals.USB_BUF.buffer_control.ep0.device.out0.read().transfer_pending) {
            while (!peripherals.USB_DEV.ep_abort_complete.read().ep0.out) {}
            peripherals.USB_BUF.buffer_control.ep0.device.out0.write(.{});
            log.debug("ep0 out aborted", .{});
        }
        peripherals.USB_DEV.ep_abort.clearBits(.{ .ep0 = .{ .in = true, .out = true }});
    }

    return .{
        .buffer_ready = s.buffer_transfer_complete or stalled_or_waiting != 0,
        .bus_reset = s.bus_reset,
        .setup_request = s.setup_request,
    };
}

pub fn getSetupPacket() SetupPacket {
    var raw: packed struct (u64) {
        low: u32,
        high: u32,
    } = .{
        .low = peripherals.USB_BUF.setup_packet_low.read(),
        .high = peripherals.USB_BUF.setup_packet_high.read(),
    };

    return @bitCast(raw);
}

pub fn setAddress(address: u7) void {
    peripherals.USB_DEV.address.write(address);
}

pub fn configureEndpoint(ed: descriptor.Endpoint) void {
    const buffer = endpointBufferIndex(ed.address);
    var dpram_base = @intFromPtr(peripherals.USB_BUF);
    var buffer_base = @intFromPtr(&peripherals.USB_BUF.buffer[buffer]);
    var base_offset: u16 = @intCast(buffer_base - dpram_base);

    getEndpointControl(ed.address).write(.{
        .buffer_base = @intCast(@shrExact(base_offset, 6)),
        .transfer_kind = ed.transfer_kind,
        .enable_buffer_interrupt = true,
        .enabled = true,
    });
}

pub fn bufferIterator() BufferIterator {
    const raw = peripherals.USB_DEV.buffer_transfer_complete.raw | stalled_or_waiting;
    return .{
        .bitmap = raw,
        .next_index = if (raw == 0) 32 else @ctz(raw),
    };
}
const BufferIterator = struct {
    bitmap: u32,
    next_index: u6,

    pub fn next(self: *BufferIterator) ?endpoint.BufferInfo {
        const current = self.next_index;
        if (current >= 32) return null;

        // You could imagine doing this more "efficiently" with @ctz, but
        // armv6-thumb doesn't have an instruction for that,
        // so it would end up the same or slower.
        var next_index = current + 1;
        var bitmap = self.bitmap >> @intCast(next_index);
        while (bitmap != 0 and 0 == @as(u1, @truncate(bitmap))) {
            next_index += 1;
            bitmap >>= 1;
        }
        if (bitmap == 0) next_index = 32;
        self.next_index = next_index;

        const ep_address: endpoint.Address = .{
            .ep = @intCast(current >> 1),
            .dir = switch (@as(u1, @truncate(current))) {
                0 => .in,
                1 => .out,
            },
        };

        clearBufferTransferCompleteFlag(ep_address);

        const buf: reg_types.usb.DeviceBufferControl0 = getBufferControl0(ep_address).read();

        return .{
            .address = ep_address,
            .buffer = getBufferData(ep_address)[0..buf.len],
            .final_buffer = buf.final_transfer,
        };
    }
};

pub fn fillBufferIn(ep: endpoint.Index, offset: isize, data: []const u8) void {
    var adjusted_data = data;
    const offset_usize: usize = if (offset < 0) s: {
        const start: usize = @intCast(-offset);
        adjusted_data = data[@min(start, data.len)..];
        break :s 0;
    } else if (offset >= 64) {
        return;
    } else @intCast(offset);

    if (offset_usize + adjusted_data.len > 64) {
        adjusted_data = adjusted_data[0 .. 64 - offset_usize];
    }

    const ep_address: endpoint.Address = .{ .ep = ep, .dir = .in };

    //std.debug.assert(getBufferControl0(ep_address).read().transfer_pending == false);
    const buffer = getBufferData(ep_address);
    @memcpy(buffer[offset_usize..].ptr, adjusted_data);

    log.debug("{X:0>8}: {}", .{ @intFromPtr(buffer), std.fmt.fmtSliceHexLower(@volatileCast(buffer)) });
}

pub fn startTransferIn(ep: endpoint.Index, len: usize, pid: PID, last_buffer: bool) void {
    const ep_address = .{ .ep = ep, .dir = .in };

    const bc = getBufferControl0(ep_address);
    var bc_value: @TypeOf(bc.*).Type = .{
        .len = @intCast(len),
        .pid = pid,
        .full = true,
    };
    if (last_buffer) bc_value.final_transfer = true;
    bc.write(bc_value);

    // At max clk_sys, 3 cycles is sufficient to ensure our config was written correctly,
    // and adding .transfer_pending below takes 1 cycle, so we just need 2 more:
    asm volatile (
        \\nop
        \\nop
    ::: "memory"); // dirtying "memory" ensures LLVM can't hoist bc_value.transfer_pending = true above the original bc.write

    bc_value.transfer_pending = true;
    bc.write(bc_value);

    stalled_or_waiting &= ~endpointAddressMask(ep_address);
}

pub fn startTransferOut(ep: endpoint.Index, len: usize, pid: PID, last_buffer: bool) void {
    var ep_address: endpoint.Address = .{ .ep = ep, .dir = .out };

    const bc = getBufferControl0(ep_address);
    var bc_value: @TypeOf(bc.*).Type = .{
        .len = @intCast(len),
        .pid = pid,
        .full = false,
    };
    if (last_buffer) bc_value.final_transfer = true;
    bc.write(bc_value);

    // At max clk_sys, 3 cycles is sufficient to ensure our config was written correctly,
    // and adding .transfer_pending below takes 1 cycle, so we just need 2 more:
    asm volatile (
        \\nop
        \\nop
    ::: "memory"); // dirtying "memory" ensures LLVM can't hoist bc_value.transfer_pending = true above the original bc.write

    bc_value.transfer_pending = true;
    bc.write(bc_value);

    stalled_or_waiting &= ~endpointAddressMask(ep_address);
}

pub fn startStall(address: endpoint.Address) void {
    log.debug("ep{} {s} stalling", .{ address.ep, @tagName(address.dir) });
    getBufferControl0(address).write(.{ .send_stall = true });
    stalled_or_waiting |= endpointAddressMask(address);
}

pub fn startNak(address: endpoint.Address) void {
    log.debug("ep{} {s} nakking", .{ address.ep, @tagName(address.dir) });
    getBufferControl0(address).write(.{});
    stalled_or_waiting |= endpointAddressMask(address);
}

fn getBufferData(ep_address: endpoint.Address) *volatile [64]u8 {
    if (ep_address.ep == 0) {
        return &peripherals.USB_BUF.buffer[0];
    } else {
        const ec: reg_types.usb.DeviceEndpointControl = getEndpointControl(ep_address).read();
        const buffer_index: usize = ec.buffer_base;
        const buffer_offset: usize = buffer_index * 64;
        return @ptrFromInt(@intFromPtr(peripherals.USB_BUF) + buffer_offset);
    }
}

fn getEndpointControl(ep_address: endpoint.Address) *volatile Mmio(reg_types.usb.DeviceEndpointControl, .rw) {
    const io = switch (ep_address.ep) {
        0 => unreachable,
        1 => &peripherals.USB_BUF.ep_control.ep1.device,
        2 => &peripherals.USB_BUF.ep_control.ep2.device,
        3 => &peripherals.USB_BUF.ep_control.ep3.device,
        4 => &peripherals.USB_BUF.ep_control.ep4.device,
        5 => &peripherals.USB_BUF.ep_control.ep5.device,
        6 => &peripherals.USB_BUF.ep_control.ep6.device,
        7 => &peripherals.USB_BUF.ep_control.ep7.device,
        8 => &peripherals.USB_BUF.ep_control.ep8.device,
        9 => &peripherals.USB_BUF.ep_control.ep9.device,
        10 => &peripherals.USB_BUF.ep_control.ep10.device,
        11 => &peripherals.USB_BUF.ep_control.ep11.device,
        12 => &peripherals.USB_BUF.ep_control.ep12.device,
        13 => &peripherals.USB_BUF.ep_control.ep13.device,
        14 => &peripherals.USB_BUF.ep_control.ep14.device,
        15 => &peripherals.USB_BUF.ep_control.ep15.device,
    };

    return switch (ep_address.dir) {
        .in => &io.in,
        .out => &io.out,
    };
}

fn getBufferControl0(ep_address: endpoint.Address) *volatile Mmio(reg_types.usb.DeviceBufferControl0, .rw) {
    const io = switch (ep_address.ep) {
        0 => &peripherals.USB_BUF.buffer_control.ep0.device,
        1 => &peripherals.USB_BUF.buffer_control.ep1.device,
        2 => &peripherals.USB_BUF.buffer_control.ep2.device,
        3 => &peripherals.USB_BUF.buffer_control.ep3.device,
        4 => &peripherals.USB_BUF.buffer_control.ep4.device,
        5 => &peripherals.USB_BUF.buffer_control.ep5.device,
        6 => &peripherals.USB_BUF.buffer_control.ep6.device,
        7 => &peripherals.USB_BUF.buffer_control.ep7.device,
        8 => &peripherals.USB_BUF.buffer_control.ep8.device,
        9 => &peripherals.USB_BUF.buffer_control.ep9.device,
        10 => &peripherals.USB_BUF.buffer_control.ep10.device,
        11 => &peripherals.USB_BUF.buffer_control.ep11.device,
        12 => &peripherals.USB_BUF.buffer_control.ep12.device,
        13 => &peripherals.USB_BUF.buffer_control.ep13.device,
        14 => &peripherals.USB_BUF.buffer_control.ep14.device,
        15 => &peripherals.USB_BUF.buffer_control.ep15.device,
    };

    return switch (ep_address.dir) {
        .in => &io.in0,
        .out => &io.out0,
    };
}

fn endpointBufferIndex(ep_address: endpoint.Address) u5 {
    var index: u5 = ep_address.ep;
    index *= 2;
    if (ep_address.dir == .out) index += 1;
    return index;
}

fn endpointAddressMask(ep_address: endpoint.Address) u32 {
    return @as(u32, 1) << endpointBufferIndex(ep_address);
}

fn clearBufferTransferCompleteFlag(ep_address: endpoint.Address) void {
    const mask = endpointAddressMask(ep_address);
    chip.clearRegisterBits(&peripherals.USB_DEV.buffer_transfer_complete.raw, mask);
}
