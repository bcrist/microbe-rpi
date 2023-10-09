const std = @import("std");
const chip = @import("chip");
const microbe = @import("microbe");

comptime {
    chip.initExports();
}

pub const panic = microbe.defaultPanic;
pub const std_options = struct {
    pub const logFn = microbe.defaultLog;
};

pub const clocks: chip.clocks.Config = .{
    .xosc = .{},
    .sys_pll = .{ .frequency_hz = 100_000_000 },
    .uart_spi = .{},
};

pub const handlers = struct {
    pub const SysTick = chip.timing.handleTickInterrupt;

    pub fn UART0_IRQ() callconv(.C) void {
        debug_uart.handleInterrupt();
    }
};

pub var debug_uart: chip.Uart(.{
    .baud_rate = 9600,
    .parity = .even,
    .tx = .GPIO0,
    .rx = .GPIO1,
    .cts = .GPIO2,
    .rts = .GPIO3,
    .tx_buffer_size = 256,
    .rx_buffer_size = 256,
}) = undefined;


const TestBus = microbe.bus.Bus(&.{ .GPIO4, .GPIO5, .GPIO6, .GPIO11, .GPIO10 }, .{ .name = "Test", .gpio_config = .{} });

pub fn main() void {
    debug_uart = @TypeOf(debug_uart).init();
    debug_uart.start();

    TestBus.init();
    TestBus.modifyInline(7);
    TestBus.modifyInline(17);
    TestBus.modifyInline(7);

    var writer = debug_uart.writer();
    var reader = debug_uart.reader();

    while (true) {
        if (debug_uart.canRead()) {
            writer.writeByte(':') catch unreachable;

            while (debug_uart.canRead()) {
                var b = reader.readByte() catch |err| {
                    const s = switch (err) {
                        error.Overrun => "!ORE!",
                        error.FramingError => "!FE!",
                        error.ParityError => "!PE!",
                        error.BreakInterrupt => "!BRK!",
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
