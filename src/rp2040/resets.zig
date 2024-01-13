pub fn reset(comptime which: anytype) void {
    hold_in_reset(which);
    ensure_not_in_reset(which);
}

pub fn hold_in_reset(comptime which: anytype) void {
    peripherals.RESETS.force.set_bits(which);
}

pub fn ensure_not_in_reset(comptime which: anytype) void {
    peripherals.RESETS.force.clear_bits(which);
    const mask = @TypeOf(peripherals.RESETS.force).get_bit_mask(which);

    while ((peripherals.RESETS.done.raw & mask) != mask) {
        asm volatile ("" ::: "memory");
    }
}

const peripherals = @import("peripherals.zig");
const reg_types = @import("reg_types.zig");
const std = @import("std");
