
pub fn init_exports() void {
    @export(&boot.boot3, .{ .name = "_boot3", .section = ".boot3_entry" });
    @export(&boot.core0_vt, .{ .name = "_core0_vt", .section = ".core0_vt" });
    @export(&boot.core1_vt, .{ .name = "_core1_vt", .section = ".core1_vt" });
}

pub const reg_types = @import("rp2040/reg_types.zig");
pub const peripherals = @import("rp2040/peripherals.zig");

pub const boot = @import("rp2040/boot.zig");
pub const validation = @import("rp_common/validation.zig");

pub const interrupts = @import("rp_common/interrupts.zig");
pub const Interrupt = interrupts.Interrupt;
pub const Exception = interrupts.Exception;

pub const gpio = @import("rp2040/gpio.zig");
pub const dma = @import("rp2040/dma.zig");
pub const clocks = @import("rp2040/clocks.zig");
pub const timing = @import("rp2040/timing.zig");
pub const resets = @import("rp2040/resets.zig");
pub const pwm = @import("rp_common/pwm.zig");
pub const PWM = pwm.PWM;
pub const uart = @import("rp_common/uart.zig");
pub const UART = uart.UART;
pub const spi = @import("rp_common/spi.zig");
pub const usb = @import("rp_common/usb.zig");

pub const base_name = "RP2040";
pub const core_name = "ARM Cortex-M0+";

pub const Pad_ID = enum (u8) {
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

pub inline fn flush_instruction_cache() void {
    asm volatile ("isb");
}
pub inline fn instruction_fence() void {
    asm volatile ("dsb");
}
pub inline fn memory_fence() void {
    asm volatile ("dmb");
}

pub fn panic_hang() noreturn {
    if (interrupts.is_in_handler()) {
        asm volatile (
            \\ mov sp, %[sp]
            \\ push {%[psr]}
            \\ push {%[hang]}
            \\ push {%[hang]}
            \\ push {r0}
            \\ push {r0,r1,r2,r3}
            \\ bx %[return_to_thread]
            :
            : [sp] "r" (boot.get_initial_stack_pointer()),
              [psr] "r" (0x0100_0000),
              [hang] "r" (microbe.hang),
              [return_to_thread] "r" (0xFFFFFFF9)
            : "memory"
        );
        unreachable;
    } else {
        microbe.hang();
    }
}

pub inline fn register_has_atomic_aliases(comptime reg: *volatile u32) bool {
    const addr = @intFromPtr(reg);
    if ((addr & 0xFFFFF000) == 0x50100000) return false; // USB DPRAM
    if ((addr & 0xE0000000) == 0x40000000) return true; // APB & AHB peripherals
    if ((addr & 0xFF000000) == 0x18000000) return true; // SSI peripheral
    if ((addr & 0xFF000000) == 0x14000000) return true; // XIP control regs
    return false;
}

pub inline fn modify_register(comptime reg: *volatile u32, comptime bits_to_set: u32, comptime bits_to_clear: u32) void {
    if (comptime register_has_atomic_aliases(reg)) {
        if (bits_to_set == 0) {
            if (bits_to_clear != 0) {
                clear_register_bits(reg, bits_to_clear);
            }
        } else if (bits_to_clear == 0) {
            set_register_bits(reg, bits_to_set);
        } else {
            const old = reg.*;
            var val = old;
            val |= bits_to_set;
            val &= ~bits_to_clear;
            toggle_register_bits(reg, val ^ old);
        }
    } else {
        var val = reg.*;
        val |= bits_to_set;
        val &= ~bits_to_clear;
        reg.* = val;
    }
}

pub inline fn toggle_register_bits(comptime reg: *volatile u32, bits_to_toggle: u32) void {
    if (comptime register_has_atomic_aliases(reg)) {
        const ptr: *volatile u32 = @ptrFromInt(@intFromPtr(reg) | 0x1000);
        ptr.* = bits_to_toggle;
    } else {
        var val = reg.*;
        val ^= bits_to_toggle;
        reg.* = val;
    }
}

pub inline fn set_register_bits(comptime reg: *volatile u32, bits_to_set: u32) void {
    if (comptime register_has_atomic_aliases(reg)) {
        const ptr: *volatile u32 = @ptrFromInt(@intFromPtr(reg) | 0x2000);
        ptr.* = bits_to_set;
    } else {
        var val = reg.*;
        val |= bits_to_set;
        reg.* = val;
    }
}

pub inline fn clear_register_bits(comptime reg: *volatile u32, bits_to_clear: u32) void {
    if (comptime register_has_atomic_aliases(reg)) {
        const ptr: *volatile u32 = @ptrFromInt(@intFromPtr(reg) | 0x3000);
        ptr.* = bits_to_clear;
    } else {
        var val = reg.*;
        val &= ~bits_to_clear;
        reg.* = val;
    }
}

const microbe = @import("microbe");
