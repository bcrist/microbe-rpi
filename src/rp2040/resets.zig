const std = @import("std");
const peripherals = @import("peripherals.zig");
const reg_types = @import("reg_types.zig");

pub fn reset(comptime which: anytype) void {
    holdInReset(which);
    ensureNotInReset(which);
}

pub fn holdInReset(comptime which: anytype) void {
    peripherals.RESETS.force.setBits(which);
}

pub fn ensureNotInReset(comptime which: anytype) void {
    peripherals.RESETS.force.clearBits(which);
    const mask = @TypeOf(peripherals.RESETS.force).getBitMask(which);

    while ((peripherals.RESETS.done.raw & mask) != mask) {
        asm volatile ("" ::: "memory");
    }
}
