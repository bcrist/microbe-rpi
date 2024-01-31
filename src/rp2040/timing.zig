pub inline fn blockAtLeastCycles(min_cycles: u32) void {
    asm volatile (
        \\1: subs %[reg], #3
        \\bhs 1b
        :: [reg] "r" (min_cycles) : "%[reg]"
    );
}

var current_tick_raw: u32 = 0;
pub fn current_tick() microbe.Tick {
    return @enumFromInt(current_tick_raw);
}

pub fn block_until_tick(tick: microbe.Tick) void {
    while (current_tick().is_before(tick)) {
        asm volatile ("" ::: "memory");
    }
}

pub fn get_tick_frequency_hz() comptime_int {
    return clocks.get_config().tick.frequency_hz;
}

pub fn handle_tick_interrupt() callconv(.C) void {
    if (peripherals.SYSTICK.control_status.read().overflow_flag) {
        current_tick_raw +%= 1;
    }
}

pub fn current_microtick() microbe.Microtick {
    var h = peripherals.TIMER.read_tick_unlatched.high.read();
    while (true) {
        const l = peripherals.TIMER.read_tick_unlatched.low.read();
        const h2 = peripherals.TIMER.read_tick_unlatched.high.read();
        if (h == h2) {
            const combined = (@as(u64, h) << 32) | l; 
            return @enumFromInt(combined);
        }
        h = h2;
    }
}

pub fn block_until_microtick(tick: microbe.Microtick) void {
    while (current_microtick().is_before(tick)) {
        asm volatile ("" ::: "memory");
    }
}

pub fn get_microtick_frequency_hz() comptime_int {
    return clocks.get_config().microtick.frequency_hz;
}

const clocks = @import("clocks.zig");
const peripherals = @import("peripherals.zig");
const microbe = @import("microbe");
const std = @import("std");
