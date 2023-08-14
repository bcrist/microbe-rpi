const common = @import("rp2040/common.zig");
pub const reg_types = @import("rp2040/reg_types.zig");
pub usingnamespace @import("rp2040/peripherals.zig");
//pub const gpio = @import("gpio.zig");
//pub const interrupts = @import("interrupts.zig");
//pub const uart = @import("rp2040/uart.zig");
//pub const dma = @import("rp2040/dma.zig");
//pub const clocks = @import("rp2040/clocks.zig");

comptime {
    _ = @import("rp2040/common.zig");
}

pub const base_name = "RP2040";
pub const core_name = "ARM Cortex-M0+";

pub const PadID = enum {
    GPIO0, // pin 2
    GPIO1, // pin 3
    GPIO2, // pin 4
    GPIO3, // pin 5
    GPIO4, // pin 6
    GPIO5, // pin 7
    GPIO6, // pin 8
    GPIO7, // pin 9
    GPIO8, // pin 11
    GPIO9, // pin 12
    GPIO10, // pin 13
    GPIO11, // pin 14
    GPIO12, // pin 15
    GPIO13, // pin 16
    GPIO14, // pin 17
    GPIO15, // pin 18
    GPIO16, // pin 27
    GPIO17, // pin 28
    GPIO18, // pin 29
    GPIO19, // pin 30
    GPIO20, // pin 31
    GPIO21, // pin 32
    GPIO22, // pin 34
    GPIO23, // pin 35
    GPIO24, // pin 36
    GPIO25, // pin 37
    GPIO26, // pin 38
    GPIO27, // pin 39
    GPIO28, // pin 40
    GPIO29, // pin 41
    SWCLK, // pin 24
    SWDIO, // pin 25
};
