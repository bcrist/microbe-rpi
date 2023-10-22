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
    .usb_pll = .{ .frequency_hz = 48_000_000 },
    .usb = .{ .frequency_hz = 48_000_000 },
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

var usb: microbe.usb.Usb(struct {
    const descriptor = microbe.usb.descriptor;
    const endpoint = microbe.usb.endpoint;

    pub fn getDeviceDescriptor() descriptor.Device {
        return .{
            .usb_version = .usb_1_1,
            .class = microbe.usb.hid.class.default,
            .vendor_id = 0x0000,
            .product_id = 0x0000,
            .version = .{ .major = 1 },
            .configuration_count = 1,
        };
    }

    const strings = struct {
        const languages: descriptor.SupportedLanguages(&.{ .english_us }) = .{};
        const mfr_name: descriptor.String("Macrofluff") = .{};
        const product_name: descriptor.String("Wonderstuff") = .{};
        const serial_number: descriptor.String("12345") = .{};
        const empty: descriptor.String("") = .{};
    };

    pub fn getStringDescriptor(id: descriptor.StringID, language: u16) []const u8 {
        _ = language;
        return switch (id) {
            .languages => std.mem.asBytes(&strings.languages),
            .manufacturer_name => std.mem.asBytes(&strings.mfr_name),
            .product_name => std.mem.asBytes(&strings.product_name),
            .serial_number => std.mem.asBytes(&strings.serial_number),
            else => std.mem.asBytes(&strings.empty),
        };
    }

    const config_set: struct {
        config: descriptor.Configuration = .{
            .number = 0,
            .length_bytes = @sizeOf(descriptor.Configuration) + @sizeOf(descriptor.Interface) + @sizeOf(descriptor.Endpoint),
            .interface_count = 1,
            .self_powered = false,
            .remote_wakeup = false,
            .max_current_ma_div2 = 40,
            .name = .default_configuration_name,
        },
        interface: descriptor.Interface = .{
            .number = 0,
            .endpoint_count = 1,
            .class = microbe.usb.hid.class.default,
            .name = .default_interface_name,
        },
        endpoint: descriptor.Endpoint = .{
            .address = .{ .ep = 1, .dir = .in },
            .transfer_kind = .interrupt,
            .poll_interval_ms = 100,
        },
    } = .{};

    pub fn getConfigurationDescriptor(configuration: u8) descriptor.Configuration {
        _ = configuration;
        return config_set.config;
    }
    pub fn getInterfaceDescriptor(configuration: u8, interface: u8) descriptor.Interface {
        _ = interface;
        _ = configuration;
        return config_set.interface;
    }
    pub fn getEndpointDescriptor(configuration: u8, interface: u8, index: u8) descriptor.Endpoint {
        _ = index;
        _ = interface;
        _ = configuration;
        return config_set.endpoint;
    }
    pub fn getDescriptor(kind: descriptor.Kind, configuration: u8, index: u8) []const u8 {
        _ = index;
        _ = configuration;
        _ = kind;
        return &.{};
    }
    pub fn isEndpointReady(address: endpoint.Address) bool {
        _ = address;
        return true;
    }
    pub fn handleOutBuffer(ep: endpoint.Index, data: []volatile const u8) void {
        _ = data;
        _ = ep;
    }
    pub fn fillInBuffer(ep: endpoint.Index, data: []u8) u16 {
        _ = ep;
        _ = data;
        return 0;
    }

}) = .{};


const TestBus = microbe.bus.Bus(&.{ .GPIO4, .GPIO5, .GPIO6, .GPIO11, .GPIO10 }, .{ .name = "Test", .gpio_config = .{} });

pub fn main() void {
    debug_uart = @TypeOf(debug_uart).init();
    debug_uart.start();

    TestBus.init();
    TestBus.modifyInline(7);
    TestBus.modifyInline(17);
    TestBus.modifyInline(7);

    usb.init();
    defer usb.deinit();

    var writer = debug_uart.writer();
    var reader = debug_uart.reader();

    while (true) {
        usb.update();

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
