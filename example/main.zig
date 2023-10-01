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
};

// pub var uart1: microbe.uart.Uart(.{
//     .baud_rate = 9600,
//     .tx = .PA9,
//     .rx = .PA10,
//     // .cts = .PA11,
//     // .rts = .PA12,
// }) = undefined;


const TestBus = microbe.bus.Bus(&.{ .GPIO2, .GPIO3, .GPIO4, .GPIO6, .GPIO7 }, .{ .name = "Test", .gpio_config = .{} });

pub fn main() !void {
    TestBus.init();
    TestBus.modifyInline(7);
    TestBus.modifyInline(17);
    TestBus.modifyInline(7);

    // uart1 = @TypeOf(uart1).init();
    // uart1.start();

    while (true) {
        // if (uart1.canRead()) {
            // var writer = uart1.writer();
            // var reader = uart1.reader();

            // try writer.writeAll(":");

            // while (uart1.canRead()) {
            //     var b = reader.readByte() catch |err| {
            //         const s = switch (err) {
            //             error.Overrun => "!ORE!",
            //             error.FramingError => "!FE!",
            //             error.NoiseError =>   "!NE!",
            //             error.EndOfStream => "!EOS!",
            //             error.BreakInterrupt => "!BRK!",
            //         };
            //         try writer.writeAll(s);
            //         continue;
            //     };

            //     switch (b) {
            //         ' '...'[', ']'...'~' => try writer.writeByte(b),
            //         else => try writer.print("\\x{x}", .{ b }),
            //     }
            // }

            // try writer.writeAll("\r\n");
        // }

        chip.timing.blockUntilMicrotick(chip.timing.currentMicrotick().plus(.{ .seconds = 2 }));
    }
}
