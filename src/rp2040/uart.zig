const std = @import("std");
const chip = @import("chip");
const microbe = @import("microbe");
const util = microbe.util;
const dma = @import("dma.zig");
const clocks = @import("clocks.zig");
const resets = @import("resets.zig");
const validation = @import("validation.zig");
const reg_types = @import("reg_types.zig");
const peripherals = @import("peripherals.zig");
const interrupts = @import("interrupts.zig");
const gpio = @import("gpio.zig");

const PadID = chip.PadID;
pub const DataBits = reg_types.uart.DataBits;
pub const Parity = reg_types.uart.Parity;
pub const StopBits = reg_types.uart.StopBits;
const ReadErrorBitmap = reg_types.uart.ReadErrorBitmap;

pub const Config = struct {
    name: [*:0]const u8 = "UART",
    clocks: clocks.ParsedConfig = clocks.getConfig(),
    baud_rate: comptime_int,
    data_bits: DataBits = .eight,
    parity: Parity = .none,
    stop_bits: StopBits = .one,
    tx: ?PadID,
    rx: ?PadID,
    cts: ?PadID = null,
    rts: ?PadID = null,
    tx_buffer_size: comptime_int = 0,
    rx_buffer_size: comptime_int = 0,
    tx_dma_channel: ?dma.Channel = null,
    rx_dma_channel: ?dma.Channel = null,
};

pub fn Uart(comptime config: Config) type {
    return comptime blk: {
        var want_uart0 = false;
        var want_uart1 = false;
        var want_dma = false;

        var pads: []const PadID = &.{};
        var output_pads: []const PadID = &.{};
        var input_pads: []const PadID = &.{};

        if (config.tx) |tx| {
            switch (tx) {
                .GPIO0, .GPIO12, .GPIO16, .GPIO28 => want_uart0 = true,
                .GPIO4, .GPIO8, .GPIO20, .GPIO24 => want_uart1 = true,
                else => @compileError("Invalid TX pad ID"),
            }
            pads = pads ++ [_]PadID{tx};
            output_pads = output_pads ++ [_]PadID{tx};
            validation.pads.reserve(tx, config.name ++ ".TX");

            if (config.cts) |cts| {
                switch (cts) {
                    .GPIO2, .GPIO14, .GPIO18 => want_uart0 = true,
                    .GPIO6, .GPIO10, .GPIO22, .GPIO26 => want_uart1 = true,
                    else => @compileError("Invalid CTS pad ID"),
                }
                if (want_uart0 and want_uart1) {
                    @compileError("CTS and TX pads must be associated with the same UART interface");
                }
                pads = pads ++ [_]PadID{cts};
                input_pads = input_pads ++ [_]PadID{cts};
                validation.pads.reserve(cts, config.name ++ ".CTS");
            }

            if (config.tx_dma_channel) |_| {
                want_dma = true;
            }
        } else if (config.tx_dma_channel) |_| {
            @compileError("TX pad not specified!");
        } else if (config.tx_buffer_size > 0) {
            @compileError("TX pad not specified!");
        }

        if (config.rx) |rx| {
            switch (rx) {
                .GPIO1, .GPIO13, .GPIO17, .GPIO29 => want_uart0 = true,
                .GPIO5, .GPIO9, .GPIO21, .GPIO25 => want_uart1 = true,
                else => @compileError("Invalid RX pad ID"),
            }
            if (want_uart0 and want_uart1) {
                @compileError("TX and RX pads must be associated with the same UART interface");
            }
            pads = pads ++ [_]PadID{rx};
            input_pads = input_pads ++ [_]PadID{rx};
            validation.pads.reserve(rx, config.name ++ ".RX");

            if (config.rts) |rts| {
                switch (rts) {
                    .GPIO3, .GPIO15, .GPIO19 => want_uart0 = true,
                    .GPIO7, .GPIO11, .GPIO23, .GPIO27 => want_uart1 = true,
                    else => @compileError("Invalid RTS pad ID"),
                }
                if (want_uart0 and want_uart1) {
                    @compileError("RX and RTS pads must be associated with the same UART interface");
                }
                pads = pads ++ [_]PadID{rts};
                output_pads = output_pads ++ [_]PadID{rts};
                validation.pads.reserve(rts, config.name ++ ".RTS");
            }

            if (config.rx_dma_channel) |_| {
                want_dma = true;
            }
        } else if (config.rx_dma_channel) |_| {
            @compileError("RX pad not specified!");
        } else if (config.rx_buffer_size > 0) |_| {
            @compileError("RX pad not specified!");
        }

        if (!want_uart0 and !want_uart1) {
            @compileError("UART without TX or RX is useless!");
        }

        if (config.rx_dma_channel != null and std.meta.eql(config.rx_dma_channel, config.tx_dma_channel)) {
            @compileError("RX and TX may not use the same DMA channel");
        }

        if (config.clocks.uart_spi.frequency_hz == 0) {
            @compileError("UART clock not configured!");
        }

        if (config.baud_rate == 0) {
            @compileError("Baud rate too low!");
        }

        const sys_clk = config.clocks.sys.frequency_hz;
        const uart_clk = config.clocks.uart_spi.frequency_hz;
        if (uart_clk * 3 > sys_clk * 5) {
            @compileError(std.fmt.comptimePrint("System clock must be at least {} for UART clock of {}", .{
                util.fmtFrequency(util.divRound(uart_clk * 3, 5)),
                util.fmtFrequency(uart_clk),
            }));
        }

        var divisor_64ths = util.divRound(uart_clk * 4, config.baud_rate);
        if (divisor_64ths < 0x40) divisor_64ths = 0x40;
        if (divisor_64ths > 0x3FFFC0) divisor_64ths = 0x3FFFC0;
        const actual_baud_rate = util.divRound(uart_clk * 4, divisor_64ths);
        if (actual_baud_rate != config.baud_rate) {
            @compileError(std.fmt.comptimePrint("Cannot achieve baud rate {}; closest possible is {}", .{
                config.baud_rate,
                actual_baud_rate,
            }));
        }

        const div_int: u16 = @intCast(divisor_64ths >> 6);
        const div_frac: u6 = @truncate(divisor_64ths);

        const periph: *volatile reg_types.uart.UART = if (want_uart0) peripherals.UART0 else peripherals.UART1;

        const Data = switch (config.data_bits) {
            .five => u5,
            .six => u6,
            .seven => u7,
            .eight => u8,
        };

        const Errors = struct {
            const ReadBase = error {
                Overrun,
                BreakInterrupt,
                FramingError,
            };
            const ReadBaseNonBlocking = ReadBase || error{ WouldBlock };

            const Read            = if (config.rx == null) error { Unimplemented } else if (config.parity == .none) ReadBase else (ReadBase || error {ParityError});
            const ReadNonBlocking = if (config.rx == null) error { Unimplemented } else if (config.parity == .none) ReadBaseNonBlocking else (ReadBaseNonBlocking || error.ParityError);

            const Write            = if (config.tx == null) error { Unimplemented } else error {};
            const WriteNonBlocking = if (config.tx == null) error { Unimplemented } else error { WouldBlock };
        };

        const Rx = rx: {
            if (config.rx == null) {
                break :rx NoRx(Data);
            } else if (config.rx_buffer_size == 0) {
                break :rx UnbufferedRx(Data, periph, Errors.Read);
            } else if (config.rx_dma_channel) |channel| {
                break :rx DmaRx(Data, periph, config.rx_buffer_size, channel);
            } else {
                break :rx InterruptRx(Data, periph, config.rx_buffer_size, Errors.Read);
            }
        };

        const Tx = tx: {
            if (config.tx == null) {
                break :tx NoTx(Data);
            } else if (config.tx_buffer_size == 0) {
                break :tx UnbufferedTx(Data, periph);
            } else if (config.tx_dma_channel) |channel| {
                break :tx DmaTx(Data, periph, config.tx_buffer_size, channel);
            } else {
                break :tx InterruptTx(Data, periph, config.tx_buffer_size);
            }
        };

        break :blk struct {
            rxi: Rx = .{},
            txi: Tx = .{},

            const Self = @This();
            pub const DataType = Data;

            pub const ReadError = Errors.Read;
            pub const Reader = std.io.Reader(*Rx, ReadError, Rx.readBlocking);

            pub const ReadErrorNonBlocking = Errors.ReadNonBlocking;
            pub const ReaderNonBlocking = std.io.Reader(*Rx, ReadErrorNonBlocking, Rx.readNonBlocking);

            pub const WriteError = Errors.Write;
            pub const Writer = std.io.Writer(*Tx, WriteError, Tx.writeBlocking);

            pub const WriteErrorNonBlocking = Errors.WriteNonBlocking;
            pub const WriterNonBlocking = std.io.Writer(*Tx, WriteErrorNonBlocking, Tx.writeNonBlocking);

            pub fn init() Self {
                { // ensure nothing we need is still in reset:
                    comptime var ensure: reg_types.sys.ResetBitmap = .{};
                    ensure.pads_bank0 = true;
                    ensure.io_bank0 = true;
                    if (want_dma) ensure.dma = true;
                    resets.ensureNotInReset(ensure);
                }
                {
                    if (want_uart0) resets.reset(.uart0);
                    if (want_uart1) resets.reset(.uart1);
                }

                periph.control.modify(.{ .enabled = false });

                gpio.setFunctionAll(pads, .uart);
                gpio.configure(output_pads, .{
                    .speed = .slow,
                    .strength = .@"4mA",
                    .output_disabled = false,
                });
                gpio.configure(input_pads, .{
                    .hysteresis = false,
                    .maintenance = .pull_up,
                    .input_enabled = true,
                });

                periph.baud_rate_int.write(.{
                    .div = div_int,
                });
                periph.baud_rate_frac.write(.{
                    .div_64ths = div_frac,
                });
                periph.line_control.write(.{
                    .parity = config.parity,
                    .stop_bits = config.stop_bits,
                    .data_bits = config.data_bits,
                    .fifos_enabled = true,
                });

                periph.control.write(.{
                    .tx_enabled = config.tx != null,
                    .rx_enabled = config.rx != null,
                    .rx_fifo_controls_rts = config.rts != null,
                    .cts_controls_tx = config.cts != null,
                });

                periph.fifo_interrupt_threshold.write(.{
                    .tx = .at_most_one_half_full,
                    .rx = .at_least_one_half_full,
                });

                if (config.tx_buffer_size > 0 or config.rx_buffer_size > 0) {
                    if (want_uart0) {
                        peripherals.NVIC.interrupt_clear_pending.write(.{ .UART0_IRQ = true });
                        peripherals.NVIC.interrupt_set_enable.write(.{ .UART0_IRQ = true });
                    } else {
                        peripherals.NVIC.interrupt_clear_pending.write(.{ .UART1_IRQ = true });
                        peripherals.NVIC.interrupt_set_enable.write(.{ .UART1_IRQ = true });
                    }
                }

                var self: Self = .{};
                self.rxi.init();
                self.txi.init();
                return self;
            }

            pub fn start(self: *Self) void {
                self.rxi.start();
                self.txi.start();
                periph.control.modify(.{ .enabled = true });
            }

            pub fn stop(self: *Self) void {
                self.txi.stop();
                self.rxi.stop();
                while (!self.txi.isIdle()) {}
                periph.control.modify(.{ .enabled = false });
            }

            pub fn deinit(self: *Self) void {
                self.txi.deinit();
                self.rxi.deinit();

                periph.control.write(.{});

                gpio.setFunctionAll(pads, .disable);

                if (want_uart0) resets.holdInReset(.uart0);
                if (want_uart1) resets.holdInReset(.uart1);
            }

            pub fn getRxAvailableCount(self: *Self) usize {
                return self.rxi.getAvailableCount();
            }

            pub fn canRead(self: *Self) bool {
                return self.rxi.getAvailableCount() > 0;
            }

            pub fn peek(self: *Self, buffer: []DataType) ReadError![]const DataType {
                return self.rxi.peek(buffer);
            }

            pub fn peekOne(self: *Self) ReadError!?DataType {
                return @call(.always_inline, self.rxi.peekByte, .{});
            }

            pub fn reader(self: *Self) Reader {
                return .{ .context = &self.rxi };
            }

            pub fn readerNonBlocking(self: *Self) ReaderNonBlocking {
                return .{ .context = &self.rxi };
            }

            pub fn isTxIdle(self: *Self) bool {
                return self.txi.isIdle();
            }

            pub fn getTxAvailableCount(self: *Self) usize {
                return self.txi.getAvailableCount();
            }

            pub fn canWrite(self: *Self) bool {
                return self.txi.getAvailableCount() > 0;
            }

            pub fn writer(self: *Self) Writer {
                return .{ .context = &self.txi };
            }

            pub fn writerNonBlocking(self: *Self) WriterNonBlocking {
                return .{ .context = &self.txi };
            }

            pub fn handleInterrupt(self: *Self) void {
                const status = periph.interrupt_status_masked.read();
                self.rxi.handleInterrupt(status);
                self.txi.handleInterrupt(status);
            }

        };
    };
}

fn NoRx(comptime DataType: type) type {
    return struct {
        const Self = @This();

        pub fn init(_: Self) void {}
        pub fn deinit(_: Self) void {}
        pub fn start(_: Self) void {}
        pub fn stop(_: Self) void {}

        pub fn getAvailableCount(_: Self) usize {
            return 0;
        }

        pub fn peek(_: Self, _: []DataType) ![]const DataType {
            return error.Unimplemented;
        }
        pub fn peekByte(_: Self) !?DataType {
            return error.Unimplemented;
        }

        pub fn readBlocking(_: *Self, _: []DataType) !usize {
            return error.Unimplemented;
        }

        pub fn readNonBlocking(_: *Self, _: []DataType) !usize {
            return error.Unimplemented;
        }

        pub fn handleInterrupt(_: Self, _: reg_types.uart.InterruptBitmap) void {}
    };
}

fn NoTx(comptime DataType: type) type {
    return struct {
        const Self = @This();

        pub fn init(_: Self) void {}
        pub fn deinit(_: Self) void {}
        pub fn start(_: Self) void {}
        pub fn stop(_: Self) void {}

        pub fn getAvailableCount(_: Self) usize {
            return 0;
        }

        pub fn writeBlocking(_: *Self, _: []const DataType) !usize {
            return error.Unimplemented;
        }

        pub fn writeNonBlocking(_: *Self, _: []const DataType) !usize {
            return error.Unimplemented;
        }

        pub fn handleInterrupt(_: Self, _: reg_types.uart.InterruptBitmap) void {}
    };
}

fn UnbufferedRx(comptime DataType: type, comptime periph: *volatile reg_types.uart.UART, comptime ReadError: type) type {
    const check_parity = util.errorSetContainsAny(ReadError, error {ParityError});

    return struct {
        peek_byte: ?DataType = null,
        pending_error: ReadErrorBitmap = .{},

        const Self = @This();

        pub fn init(_: *const Self) void {}
        pub fn deinit(_: *const Self) void {}
        pub fn start(_: *const Self) void {}
        pub fn stop(_: *const Self) void {}

        pub fn getAvailableCount(self: *const Self) usize {
            if (self.peek_byte) |_| return 1;
            if (0 != @as(u4, @bitCast(self.pending_error))) return 1;
            if (!periph.flags.read().rx_fifo_empty) return 1;
            return 0;
        }

        pub fn peek(self: *Self, out: []u8) ![]const DataType {
            if (out.len == 0) return out[0..0];

            if (try self.peekByte()) |b| {
                out[0] = b;
                return out[0..1];
            } else {
                return out[0..0];
            }
        }

        pub fn peekByte(self: *Self) !?DataType {
            if (0 != @as(u4, @bitCast(self.pending_error))) {
                if (self.pending_error.overrun) return error.Overrun;
                if (self.pending_error.framing_error) return error.FramingError;
                if (self.pending_error.break_error) return error.BreakInterrupt;
                if (check_parity and self.pending_error.parity_error) return error.ParityError;
            }

            if (self.peek_byte) |b| return b;

            if (periph.flags.read().rx_fifo_empty) return null;

            const item = periph.data.read();
            self.pending_error = item.errors;
            if (item.errors.overrun) {
                self.peek_byte = @intCast(item.data);
                return error.Overrun;
            } else if (item.errors.framing_error) {
                return error.FramingError;
            } else if (item.errors.break_error) {
                return error.BreakInterrupt;
            } else if (check_parity and item.errors.parity_error) {
                return error.ParityError;
            } else {
                const data: DataType = @intCast(item.data);
                self.peek_byte = data;
                return data;
            }
        }

        pub fn readBlocking(self: *Self, buffer: []DataType) !usize {
            for (0.., buffer) |i, *out| {
                const result = self.peekByte() catch |err| {
                    if (i > 0) return i;

                    if (err == error.Overrun) {
                        self.pending_error.overrun = false;
                    } else {
                        self.pending_error = .{};
                    }
                    return err;
                };

                if (result) |b| {
                    out.* = b;
                } else {
                    while (periph.flags.read().rx_fifo_empty) {}

                    out.* = (self.peekByte() catch |err| {
                        if (i > 0) return i;

                        if (err == error.Overrun) {
                            self.pending_error.overrun = false;
                        } else {
                            self.pending_error = .{};
                        }
                        return err;
                    }).?;
                }

                self.peek_byte = null;
            }

            return buffer.len;
        }

        pub fn readNonBlocking(self: *Self, buffer: []DataType) !usize {
            for (0.., buffer) |i, *out| {
                const result = self.peekByte() catch |err| {
                    if (i > 0) return i;

                    if (err == error.Overrun) {
                        self.pending_error.overrun = false;
                    } else {
                        self.pending_error = .{};
                    }
                    return err;
                };

                if (result) |b| {
                    out.* = b;
                    self.peek_byte = null;
                } else if (i > 0) {
                    return i;
                } else {
                    return error.WouldBlock;
                }
            }

            return buffer.len;
        }

        pub fn handleInterrupt(_: Self, _: reg_types.uart.InterruptBitmap) void {}
    };
}

fn UnbufferedTx(comptime DataType: type, comptime periph: *volatile reg_types.uart.UART) type {
    return struct {
        const Self = @This();

        pub fn init(_: Self) void {}
        pub fn deinit(_: Self) void {}
        pub fn start(_: Self) void {}
        pub fn stop(_: Self) void {}

        pub fn isIdle(_: Self) bool {
            return !periph.flags.read().tx_in_progress;
        }

        pub fn getAvailableCount(_: Self) usize {
            return if (periph.flags.read().tx_fifo_full) 0 else 1;
        }

        pub fn writeBlocking(_: *Self, data: []const DataType) !usize {
            for (data) |b| {
                while (periph.flags.read().tx_fifo_full) {}
                periph.data.write(.{ .data = b });
            }
            return data.len;
        }

        pub fn writeNonBlocking(_: *Self, data: []const DataType) !usize {
            for (0.., data) |i, b| {
                if (periph.flags.read().tx_fifo_full) {
                    return if (i > 0) i else error.WouldBlock;
                }
                periph.data.write(.{ .data = b });
            }
        }

        pub fn handleInterrupt(_: Self, _: reg_types.uart.InterruptBitmap) void {}
    };
}

const ReadErrorPack = packed struct (u16) {
    data_bytes: u12 = 0, // after errors chronologically
    errors: ReadErrorBitmap = .{},

    pub fn hasError(self: ReadErrorPack) bool {
        return 0 != @as(u4, @bitCast(self.errors));
    }
};

fn InterruptRx(comptime DataType: type, comptime periph: *volatile reg_types.uart.UART, comptime buffer_size: usize, comptime ReadError: type) type {
    const check_parity = util.errorSetContainsAll(ReadError, error{ParityError});
    const pack_buffer_size = @max(@min(8, buffer_size), buffer_size / 8);
    const DataFifo = std.fifo.LinearFifo(DataType, .{ .Static = buffer_size });
    const PackFifo = std.fifo.LinearFifo(ReadErrorPack, .{ .Static = pack_buffer_size });

    if (!std.math.isPowerOfTwo(buffer_size)) {
        @compileError("UART buffer size must be a power of two!");
    }

    return struct {
        data: DataFifo = undefined,
        packs: PackFifo = undefined,
        stopped: bool = true,

        const Self = @This();

        pub fn init(self: *Self) void {
            self.data = DataFifo.init();
            self.packs = PackFifo.init();
            self.stopped = true;
        }
        pub fn deinit(self: *Self) void {
            self.stop();
            self.packs.deinit();
            self.data.deinit();
        }
        pub fn start(self: *Self) void {
            self.stopped = false;
            self.enableInterrupt();
        }
        pub fn stop(self: *Self) void {
            self.stopped = true;
            self.disableInterrupt();
        }

        pub fn getAvailableCount(self: *Self) usize {
            const amount = self.data.readableLength();
            if (amount == 0) {
                return self.packs.readableLength();
            }
            return amount;
        }

        pub fn peek(self: *Self, out: []DataType) ![]const DataType {
            if (out.len == 0) return out[0..0];

            // Note since we never modify the FIFOs here, we don't need to disable interrupts.
            // If it interrupts us and adds more data it's not a problem.

            var dest_offset: usize = 0;
            outer: for (0..self.packs.readableLength()) |pack_index| {
                const pack: ReadErrorPack = self.packs.peekItem(pack_index);

                if (pack.hasError()) {
                    if (dest_offset == 0) {
                        if (pack.errors.overrun) return error.Overrun;
                        if (pack.errors.framing_error) return error.FramingError;
                        if (pack.errors.break_error) return error.BreakInterrupt;
                        if (check_parity) {
                            if (pack.errors.parity_error) return error.ParityError;
                        } else std.debug.assert(!pack.errors.parity_error);
                    } else {
                        break :outer;
                    }
                }

                var num_data_byte = pack.data_bytes;
                while (num_data_byte > 0) {
                    var bytes = self.data.readableSlice(dest_offset);
                    if (bytes.len > num_data_byte) {
                        bytes = bytes[0..num_data_byte];
                    }

                    if (dest_offset + bytes.len >= out.len) {
                        @memcpy(out[dest_offset..], bytes.ptr);
                        break :outer;
                    }

                    @memcpy(out[dest_offset..].ptr, bytes);
                    dest_offset += bytes.len;
                    num_data_byte -= bytes.len;
                }
            }

            return out[0..dest_offset];
        }

        pub fn peekByte(self: *Self) !?DataType {
            var buf: [1]DataType = undefined;
            const result = try self.peek(&buf);
            if (result.len > 0) return result[0];
            return null;
        }

        fn checkReadError(self: *Self, errors: ReadErrorBitmap) !void {
            if (errors.overrun) {
                self.packs.buf[self.packs.head].errors.overrun = false;
                return error.Overrun;
            }
            if (errors.framing_error) {
                self.packs.buf[self.packs.head].errors.framing_error = false;
                return error.FramingError;
            }
            if (errors.break_error) {
                self.packs.buf[self.packs.head].errors.break_error = false;
                return error.BreakInterrupt;
            }
            if (check_parity) {
                if (errors.parity_error) {
                    self.packs.buf[self.packs.head].errors.parity_error = false;
                    return error.ParityError;
                }
            } else std.debug.assert(!errors.parity_error);
        }

        pub fn readBlocking(self: *Self, out: []DataType) ReadError!usize {
            var remaining = out;
            while (remaining.len > 0) {
                const bytes_read: usize = self.readNonBlocking(out) catch |err| switch (err) {
                    error.WouldBlock => blk: {
                        while (self.packs.readableLength() == 0) {
                            self.enableInterrupt();
                            interrupts.waitForInterrupt();
                        }
                        break :blk 0;
                    },
                    else => |e| return e,
                };
                remaining = remaining[bytes_read..];
            }

            return out.len;
        }

        pub fn readNonBlocking(self: *Self, out: []DataType) (ReadError||error{WouldBlock})!usize {
            var remaining = out;
            while (remaining.len > 0) {
                if (self.packs.readableLength() == 0) {
                    if (remaining.ptr != out.ptr) break;

                    return error.WouldBlock;
                }

                var pack: ReadErrorPack = self.packs.peekItem(0);

                if (pack.hasError()) {
                    if (remaining.ptr != out.ptr) break;
                    try self.checkReadError(pack.errors);
                    unreachable;
                }

                const bytes_to_read = @min(remaining.len, pack.data_bytes);
                if (bytes_to_read > 0) {
                    var cs = microbe.CriticalSection.enter();
                    const bytes_read = self.data.read(remaining[0..bytes_to_read]);
                    cs.leave();
                    std.debug.assert(bytes_read == bytes_to_read);
                    remaining = remaining[bytes_read..];
                }

                var cs = microbe.CriticalSection.enter();
                pack = self.packs.peekItem(0);
                if (bytes_to_read < pack.data_bytes) {
                    self.packs.buf[self.packs.head].data_bytes = pack.data_bytes - bytes_to_read;
                } else {
                    self.packs.discard(1);
                }
                cs.leave();
                self.enableInterrupt();
            }

            return out.len - remaining.len;
        }

        pub fn enableInterrupt(self: *Self) void {
            if (periph.interrupt_mask.read().rx) return;
            if (self.stopped) return;
            if (self.packs.writableLength() < 2) return;
            if (self.data.writableLength() == 0) return;

            periph.interrupt_mask.setBits(.{
                .rx = true,
                .rx_timeout = true,
            });
        }

        pub fn disableInterrupt(_: *Self) void {
            periph.interrupt_mask.clearBits(.{
                .rx = true,
                .rx_timeout = true,
            });
        }

        pub fn handleInterrupt(self: *Self, status: reg_types.uart.InterruptBitmap) void {
            if (status.rx or status.rx_timeout) {
                self.tryProcessInterruptData();
            }
        }

        fn tryProcessInterruptData(self: *Self) void {
            const writable_len = self.data.writableLength();
            if (writable_len == 0 or self.packs.writableLength() < 2) {
                self.disableInterrupt();
                return;
            }

            var buf: [32]DataType = undefined;
            const max_read_count = @min(buf.len, writable_len);
            var read_count: u12 = 0;

            const errors: ReadErrorBitmap = for (0..max_read_count) |i| {
                if (periph.flags.read().rx_fifo_empty) {
                    if (read_count == 0) return;
                    break .{};
                }

                const item = periph.data.read();
                buf[i] = @intCast(item.data);

                if (0 != @as(u4, @bitCast(item.errors))) {
                    break item.errors;
                } else {
                    read_count += 1;
                }
            } else .{};

            self.data.writeAssumeCapacity(buf[0..read_count]);
            self.recordPackDataBytes(read_count);

            if (0 != @as(u4, @bitCast(errors))) {
                self.packs.writeItemAssumeCapacity(.{
                    .data_bytes = 0,
                    .errors = errors,
                });
                if (errors.overrun) {
                    self.data.writeAssumeCapacity(buf[read_count..][0..1]);
                    self.recordPackDataBytes(1);
                }
            }
        }

        fn recordPackDataBytes(self: *Self, count: u12) void {
            if (self.packs.readableLength() > 0) {
                var last_index = self.packs.head + self.packs.count - 1;
                last_index &= self.packs.buf.len - 1;
                var last_pack = self.packs.buf[last_index];
                const last_pack_bytes: u32 = last_pack.data_bytes;
                if (last_pack_bytes + count <= std.math.maxInt(u12)) {
                    last_pack.data_bytes += count;
                    self.packs.buf[last_index] = last_pack;
                    return;
                }
            }

            self.packs.writeItemAssumeCapacity(.{
                .data_bytes = count,
                .errors = .{},
            });
        }
    };
}

fn InterruptTx(comptime DataType: type, comptime periph: *volatile reg_types.uart.UART, comptime buffer_size: usize) type {
    const Fifo = std.fifo.LinearFifo(DataType, .{ .Static = buffer_size });

    if (!std.math.isPowerOfTwo(buffer_size)) {
        @compileError("UART buffer size must be a power of two!");
    }

    return struct {
        data: Fifo = undefined,
        stopped: bool = true,

        const Self = @This();

        pub fn init(self: *Self) void {
            self.data = Fifo.init();
            self.stopped = true;
        }
        pub fn deinit(self: *Self) void {
            self.stop();
            self.data.deinit();
        }
        pub fn start(self: *Self) void {
            self.stopped = false;
            self.enableInterrupt();
        }
        pub fn stop(self: *Self) void {
            self.stopped = true;
            self.disableInterrupt();
        }

        pub fn getAvailableCount(self: *Self) usize {
            return self.data.writableLength();
        }

        pub fn writeBlocking(self: *Self, data_to_write: []const DataType) !usize {
            if (data_to_write.len == 0) return 0;

            var remaining = self.writeDirect(data_to_write);
            while (remaining.len > 0) {
                var bytes_to_write = self.data.writableLength();
                while (bytes_to_write == 0) {
                    self.enableInterrupt();
                    interrupts.waitForInterrupt();
                    bytes_to_write = self.data.writableLength();
                }

                if (bytes_to_write > remaining.len) {
                    bytes_to_write = remaining.len;
                }

                var cs = microbe.CriticalSection.enter();
                self.data.writeAssumeCapacity(remaining[0..bytes_to_write]);
                cs.leave();
                remaining = remaining[bytes_to_write..];

                self.enableInterrupt();
            }

            return data_to_write.len;
        }

        pub fn writeNonBlocking(self: *Self, data_to_write: []const DataType) !usize {
            if (data_to_write.len == 0) return 0;

            const remaining = self.writeDirect(data_to_write);
            if (remaining.len == 0) return data_to_write.len;

            const bytes_to_write = @min(self.data.writableLength(), remaining.len);
            if (bytes_to_write == 0) {
                return error.WouldBlock;
            }

            var cs = microbe.CriticalSection.enter();
            self.data.writeAssumeCapacity(data_to_write[0..bytes_to_write]);
            cs.leave();
            self.enableInterrupt();
            return data_to_write.len - remaining.len + bytes_to_write;
        }

        fn writeDirect(self: *Self, data_to_write: []const DataType) []const DataType {
            var remaining = data_to_write;
            if (self.data.readableLength() == 0) {
                while (remaining.len > 0 and !periph.flags.read().tx_fifo_full) {
                    periph.data.write(.{ .data = remaining[0] });
                    remaining = remaining[1..];
                }
            }
            return remaining;
        }

        pub fn enableInterrupt(self: *Self) void {
            if (periph.interrupt_mask.read().tx) return;
            if (self.stopped) return;
            if (self.data.readableLength() == 0) return;

            periph.interrupt_mask.setBits(.tx);
        }

        pub fn disableInterrupt(_: *Self) void {
            periph.interrupt_mask.clearBits(.tx);
        }

        pub fn handleInterrupt(self: *Self, status: reg_types.uart.InterruptBitmap) void {
            if (status.tx) {
                self.tryProcessInterruptData();
            }
        }

        pub fn tryProcessInterruptData(self: *Self) void {
            const readable = self.data.readableSlice(0);
            var bytes_written: usize = 0;
            for (readable) |b| {
                if (periph.flags.read().tx_fifo_full) break;
                periph.data.write(.{ .data = b });
                bytes_written += 1;
            }
            self.data.discard(bytes_written);

            if (self.data.readableLength() == 0) {
                self.disableInterrupt();
            }
        }

    };
}

fn DmaRx(comptime DataType: type, comptime periph: *volatile reg_types.uart.UART, comptime buffer_size: usize, comptime channel: dma.Channel) type {
    _ = buffer_size;
    _ = periph;
    _ = DataType;
    _ = channel;
    @compileError("Not implemented yet");
}

fn DmaTx(comptime DataType: type, comptime periph: *volatile reg_types.uart.UART, comptime buffer_size: usize, comptime channel: dma.Channel) type {
    _ = buffer_size;
    _ = periph;
    _ = DataType;
    _ = channel;
    @compileError("Not implemented yet");
}
