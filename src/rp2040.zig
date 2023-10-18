
pub fn initExports() void {
    @export(boot.boot3, .{ .name = "_boot3", .section = ".boot3_entry" });
    @export(boot.core0_vt, .{ .name = "_core0_vt", .section = ".core0_vt" });
    @export(boot.core1_vt, .{ .name = "_core1_vt", .section = ".core1_vt" });
}

pub const reg_types = @import("rp2040/reg_types.zig");
pub usingnamespace @import("rp2040/peripherals.zig");

pub const boot = @import("rp2040/boot.zig");
pub const validation = @import("rp2040/validation.zig");

pub const interrupts = @import("rp2040/interrupts.zig");
pub const Interrupt = interrupts.Interrupt;
pub const Exception = interrupts.Exception;

pub const gpio = @import("rp2040/gpio.zig");
pub const dma = @import("rp2040/dma.zig");
pub const clocks = @import("rp2040/clocks.zig");
pub const timing = @import("rp2040/timing.zig");
pub const resets = @import("rp2040/resets.zig");
pub const uart = @import("rp2040/uart.zig");
pub const Uart = uart.Uart;
pub const usb = @import("rp2040/usb.zig");

pub const base_name = "RP2040";
pub const core_name = "ARM Cortex-M0+";

pub const PadID = enum (u8) {
    GPIO0 = 0, // pin 2
    GPIO1 = 1, // pin 3
    GPIO2 = 2, // pin 4
    GPIO3 = 3, // pin 5
    GPIO4 = 4, // pin 6
    GPIO5 = 5, // pin 7
    GPIO6 = 6, // pin 8
    GPIO7 = 7, // pin 9
    GPIO8 = 8, // pin 11
    GPIO9 = 9, // pin 12
    GPIO10 = 10, // pin 13
    GPIO11 = 11, // pin 14
    GPIO12 = 12, // pin 15
    GPIO13 = 13, // pin 16
    GPIO14 = 14, // pin 17
    GPIO15 = 15, // pin 18
    GPIO16 = 16, // pin 27
    GPIO17 = 17, // pin 28
    GPIO18 = 18, // pin 29
    GPIO19 = 19, // pin 30
    GPIO20 = 20, // pin 31
    GPIO21 = 21, // pin 32
    GPIO22 = 22, // pin 34
    GPIO23 = 23, // pin 35
    GPIO24 = 24, // pin 36
    GPIO25 = 25, // pin 37
    GPIO26 = 26, // pin 38
    GPIO27 = 27, // pin 39
    GPIO28 = 28, // pin 40
    GPIO29 = 29, // pin 41

    // SWD pins:
    SWCLK = 30, // pin 24
    SWDIO = 31, // pin 25

    // QSPI pins:
    SCLK = 32,
    SS = 33,
    SD0 = 34,
    SD1 = 35,
    SD2 = 36,
    SD3 = 37,
};

pub inline fn flushInstructionCache() void {
    asm volatile ("isb");
}
pub inline fn instructionFence() void {
    asm volatile ("dsb");
}
pub inline fn memoryFence() void {
    asm volatile ("dmb");
}

pub inline fn registerHasAtomicAliases(comptime reg: *volatile u32) bool {
    const addr = @intFromPtr(reg);
    if ((addr & 0xFFFFF000) == 0x40008000) return false; // CLOCKS
    if ((addr & 0xFFFFF000) == 0x50100000) return false; // USB DPRAM
    if ((addr & 0xE0000000) == 0x40000000) return true; // APB & AHB peripherals
    if ((addr & 0xFF000000) == 0x18000000) return true; // SSI peripheral
    if ((addr & 0xFF000000) == 0x14000000) return true; // XIP control regs
    return false;
}

pub inline fn modifyRegister(comptime reg: *volatile u32, comptime bits_to_set: u32, comptime bits_to_clear: u32) void {
    if (comptime registerHasAtomicAliases(reg)) {
        if (bits_to_set == 0) {
            if (bits_to_clear != 0) {
                clearRegisterBits(reg, bits_to_set);
            }
        } else if (bits_to_clear == 0) {
            setRegisterBits(reg, bits_to_set);
        } else {
            const old = reg.*;
            var val = old;
            val |= bits_to_set;
            val &= ~bits_to_clear;
            toggleRegisterBits(reg, val ^ old);
        }
    } else {
        var val = reg.*;
        val |= bits_to_set;
        val &= ~bits_to_clear;
        reg.* = val;
    }
}

pub inline fn toggleRegisterBits(comptime reg: *volatile u32, bits_to_toggle: u32) void {
    if (comptime registerHasAtomicAliases(reg)) {
        const ptr: *volatile u32 = @ptrFromInt(@intFromPtr(reg) | 0x1000);
        ptr.* = bits_to_toggle;
    } else {
        var val = reg.*;
        val ^= bits_to_toggle;
        reg.* = val;
    }
}

pub inline fn setRegisterBits(comptime reg: *volatile u32, bits_to_set: u32) void {
    if (comptime registerHasAtomicAliases(reg)) {
        const ptr: *volatile u32 = @ptrFromInt(@intFromPtr(reg) | 0x2000);
        ptr.* = bits_to_set;
    } else {
        var val = reg.*;
        val |= bits_to_set;
        reg.* = val;
    }
}

pub inline fn clearRegisterBits(comptime reg: *volatile u32, bits_to_clear: u32) void {
    if (comptime registerHasAtomicAliases(reg)) {
        const ptr: *volatile u32 = @ptrFromInt(@intFromPtr(reg) | 0x3000);
        ptr.* = bits_to_clear;
    } else {
        var val = reg.*;
        val &= ~bits_to_clear;
        reg.* = val;
    }
}
