const std = @import("std");
const chip = @import("chip");
const microbe = @import("microbe");
const usb = @import("usb.zig");

comptime {
    chip.init_exports();
}

pub const panic = microbe.default_panic;
pub const std_options = struct {
    pub const logFn = microbe.default_log;
};

pub const clocks: chip.clocks.Config = .{
    .xosc = .{},
    .sys_pll = .{ .frequency_hz = 100_000_000 },
    .usb_pll = .{ .frequency_hz = 48_000_000 },
    .usb = .{ .frequency_hz = 48_000_000 },
    .uart_spi = .{},
};

pub const handlers = struct {
    pub const SysTick = chip.timing.handle_tick_interrupt;

    pub fn UART0_IRQ() callconv(.C) void {
        debug_uart.handle_interrupt();
    }
};

pub var debug_uart: chip.UART(.{
    .baud_rate = 9600,
    .parity = .even,
    .tx = .GPIO0,
    .rx = .GPIO1,
    .cts = .GPIO2,
    .rts = .GPIO3,
    .tx_buffer_size = 256,
    .rx_buffer_size = 256,
}) = undefined;

pub var spi: chip.spi.Controller(.{
    .format = .spi_mode_0,
    .bit_rate = 1_000_000,
    .sck = .GPIO10,
    .tx = .GPIO11,
    .rx = .GPIO12,
    .cs = .GPIO9,
}) = undefined;

const Test_PWM = chip.PWM(.{
    .output = .GPIO20,
    .frequency_hz = 391,
    .max_count = 1000,
});

const TestBus = microbe.bus.Bus(&.{ .GPIO4, .GPIO5, .GPIO6, .GPIO14, .GPIO15 }, .{ .name = "Test", .gpio_config = .{} });

pub fn main() void {
    debug_uart = @TypeOf(debug_uart).init();
    debug_uart.start();

    spi = @TypeOf(spi).init();
    spi.start();

    Test_PWM.init();
    Test_PWM.set_threshold(128);
    Test_PWM.start();

    TestBus.init();
    TestBus.modify_inline(7);
    TestBus.modify_inline(17);
    TestBus.modify_inline(7);

    usb.init();

    var writer = debug_uart.writer();
    var reader = debug_uart.reader();

    try spi.writer().writeAll("ABC");
    var result: [3]u8 = undefined;
    _ = try spi.reader().readAll(&result);

    while (true) {
        usb.update();

        if (debug_uart.can_read()) {
            writer.writeByte(':') catch unreachable;

            while (debug_uart.can_read()) {
                const b = reader.readByte() catch |err| {
                    const s = switch (err) {
                        error.Overrun => "!ORE!",
                        error.Framing_Error => "!FE!",
                        error.Parity_Error => "!PE!",
                        error.Break_Interrupt => "!BRK!",
                        error.EndOfStream => unreachable,
                    };
                    writer.writeAll(s) catch unreachable;
                    continue;
                };

                switch (b) {
                    ' '...'[', ']'...'~' => writer.writeByte(b) catch unreachable,
                    else => writer.print("\\x{x}", .{ b }) catch unreachable,
                }
            }

            writer.writeAll("\r\n") catch unreachable;

            microbe.Tick.delay(.{ .seconds = 2 });
        }
    }
}
