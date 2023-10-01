const std = @import("std");
const chip = @import("chip");
const microbe = @import("microbe");
const clocks = @import("clocks.zig");

pub inline fn blockAtLeastCycles(min_cycles: u32) void {
    asm volatile (
        \\1: subs %[reg], #3
        \\bhs 1b
        :: [reg] "r" (min_cycles) : "%[reg]"
    );
}

var current_tick: u32 = 0;
pub fn currentTick() microbe.Tick {
    return @enumFromInt(@atomicLoad(u32, &current_tick, .SeqCst));
}

pub fn blockUntilTick(tick: microbe.Tick) void {
    while (currentTick().isBefore(tick)) {
        asm volatile ("" ::: "memory");
    }
}

pub fn getTickFrequencyHz() comptime_int {
    return clocks.getConfig().tick.frequency_hz;
}

pub fn handleTickInterrupt() callconv(.C) void {
    if (chip.SYSTICK.control_status.read().overflow_flag) {
        @atomicRmw(u32, &current_tick, .Add, 1, .SeqCst);
    }
}

pub fn currentMicrotick() microbe.Microtick {
    var h = chip.TIMER.read_tick_unlatched.high.read();
    while (true) {
        var l = chip.TIMER.read_tick_unlatched.low.read();
        var h2 = chip.TIMER.read_tick_unlatched.high.read();
        if (h == h2) {
            const combined = (@as(u64, h) << 32) | l; 
            return @enumFromInt(combined);
        }
        h = h2;
    }
}

pub fn blockUntilMicrotick(tick: microbe.Microtick) void {
    while (currentMicrotick().isBefore(tick)) {
        asm volatile ("" ::: "memory");
    }
}

pub fn getMicrotickFrequencyHz() comptime_int {
    return clocks.getConfig().microtick.frequency_hz;
}
