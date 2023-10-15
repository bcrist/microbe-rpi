const std = @import("std");
const peripherals = @import("peripherals.zig");
const reg_types = @import("reg_types.zig");

pub fn reset(which: anytype) void {
    holdInReset(which);
    ensureNotInReset(which);
}

pub fn holdInReset(which: anytype) void {
    peripherals.RESETS.force.setBits(which);
}

pub fn ensureNotInReset(which: anytype) void {
    peripherals.RESETS.force.clearBits(which);
    const mask = peripherals.RESETS.force.getBitMask(which);

    while ((peripherals.RESETS.done.raw & mask) != mask) {
        asm volatile ("" ::: "memory");
    }
}
