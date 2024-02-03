pub const Data_Bits = reg_types.uart.Data_Bits;
pub const Parity = reg_types.uart.Parity;
pub const Stop_Bits = reg_types.uart.Stop_Bits;

pub const Config = struct {
    name: [*:0]const u8 = "UART",
    clocks: clocks.Parsed_Config = clocks.get_config(),
    baud_rate: comptime_int,
    data_bits: Data_Bits = .eight,
    parity: Parity = .none,
    stop_bits: Stop_Bits = .one,
    tx: ?Pad_ID,
    rx: ?Pad_ID,
    cts: ?Pad_ID = null,
    rts: ?Pad_ID = null,
    tx_buffer_size: comptime_int = 0,
    rx_buffer_size: comptime_int = 0,
    tx_dma_channel: ?dma.Channel = null,
    rx_dma_channel: ?dma.Channel = null,
};

pub fn UART(comptime config: Config) type {
    return comptime blk: {
        var want_uart0 = false;
        var want_uart1 = false;
        var want_dma = false;

        var pads: []const Pad_ID = &.{};
        var output_pads: []const Pad_ID = &.{};
        var input_pads: []const Pad_ID = &.{};

        if (config.tx) |tx| {
            switch (tx) {
                .GPIO0, .GPIO12, .GPIO16, .GPIO28 => want_uart0 = true,
                .GPIO4, .GPIO8, .GPIO20, .GPIO24 => want_uart1 = true,
                else => @compileError("Invalid TX pad ID"),
            }
            pads = pads ++ [_]Pad_ID{tx};
            output_pads = output_pads ++ [_]Pad_ID{tx};
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
                pads = pads ++ [_]Pad_ID{cts};
                input_pads = input_pads ++ [_]Pad_ID{cts};
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
            pads = pads ++ [_]Pad_ID{rx};
            input_pads = input_pads ++ [_]Pad_ID{rx};
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
                pads = pads ++ [_]Pad_ID{rts};
                output_pads = output_pads ++ [_]Pad_ID{rts};
                validation.pads.reserve(rts, config.name ++ ".RTS");
            }

            if (config.rx_dma_channel) |_| {
                want_dma = true;
            }
        } else if (config.rx_dma_channel) |_| {
            @compileError("RX pad not specified!");
        } else if (config.rx_buffer_size > 0) {
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
                util.fmt_frequency(util.div_round(uart_clk * 3, 5)),
                util.fmt_frequency(uart_clk),
            }));
        }

        var divisor_64ths = util.div_round(uart_clk * 4, config.baud_rate);
        if (divisor_64ths < 0x40) divisor_64ths = 0x40;
        if (divisor_64ths > 0x3FFFC0) divisor_64ths = 0x3FFFC0;
        const actual_baud_rate = util.div_round(uart_clk * 4, divisor_64ths);
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
            const Read_Base = error {
                Overrun,
                Break_Interrupt,
                Framing_Error,
            };
            const Read_Base_Nonblocking = Read_Base || error{ Would_Block };

            const Read             = if (config.rx == null) error { Unimplemented } else if (config.parity == .none) Read_Base else (Read_Base || error {Parity_Error});
            const Read_Nonblocking = if (config.rx == null) error { Unimplemented } else if (config.parity == .none) Read_Base_Nonblocking else (Read_Base_Nonblocking || error.Parity_Error);

            const Write             = if (config.tx == null) error { Unimplemented } else error {};
            const Write_Nonblocking = if (config.tx == null) error { Unimplemented } else error { Would_Block };
        };

        const Rx = rx: {
            if (config.rx == null) {
                break :rx No_Rx(Data);
            } else if (config.rx_buffer_size == 0) {
                break :rx Unbuffered_Rx(Data, periph, Errors.Read);
            } else if (config.rx_dma_channel) |channel| {
                break :rx DMA_Rx(Data, periph, config.rx_buffer_size, channel);
            } else {
                break :rx Interrupt_Rx(Data, periph, config.rx_buffer_size, Errors.Read);
            }
        };

        const Tx = tx: {
            if (config.tx == null) {
                break :tx No_Tx(Data);
            } else if (config.tx_buffer_size == 0) {
                break :tx Unbuffered_Tx(Data, periph);
            } else if (config.tx_dma_channel) |channel| {
                break :tx DMA_Tx(Data, periph, config.tx_buffer_size, channel);
            } else {
                break :tx Interrupt_Tx(Data, periph, config.tx_buffer_size);
            }
        };

        break :blk struct {
            rxi: Rx = .{},
            txi: Tx = .{},

            const Self = @This();
            pub const Data_Type = Data;

            pub const Read_Error = Errors.Read;
            pub const Reader = std.io.Reader(*Rx, Read_Error, Rx.read_blocking);

            pub const Read_Error_Nonblocking = Errors.Read_Nonblocking;
            pub const Reader_Nonblocking = std.io.Reader(*Rx, Read_Error_Nonblocking, Rx.read_nonblocking);

            pub const Write_Error = Errors.Write;
            pub const Writer = std.io.Writer(*Tx, Write_Error, Tx.write_blocking);

            pub const Write_Error_Nonblocking = Errors.Write_Nonblocking;
            pub const Writer_Nonblocking = std.io.Writer(*Tx, Write_Error_Nonblocking, Tx.write_nonblocking);

            pub fn init() Self {
                { // ensure nothing we need is still in reset:
                    comptime var ensure: reg_types.sys.Reset_Bitmap = .{};
                    ensure.pads_bank0 = true;
                    ensure.io_bank0 = true;
                    if (want_dma) ensure.dma = true;
                    resets.ensure_not_in_reset(ensure);
                }
                {
                    if (want_uart0) resets.reset(.uart0);
                    if (want_uart1) resets.reset(.uart1);
                }

                periph.control.modify(.{ .enabled = false });

                gpio.set_function_all(pads, .uart);
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
                while (!self.txi.is_idle()) {}
                periph.control.modify(.{ .enabled = false });
            }

            pub fn deinit(self: *Self) void {
                self.txi.deinit();
                self.rxi.deinit();

                periph.control.write(.{});

                gpio.set_function_all(pads, .disable);

                if (want_uart0) resets.hold_in_reset(.uart0);
                if (want_uart1) resets.hold_in_reset(.uart1);
            }

            pub inline fn get_rx_available_count(self: *Self) usize {
                return self.rxi.get_available_count();
            }

            pub inline fn can_read(self: *Self) bool {
                return self.rxi.get_available_count() > 0;
            }

            pub inline fn peek(self: *Self, buffer: []Data_Type) Read_Error![]const Data_Type {
                return self.rxi.peek(buffer);
            }

            pub inline fn peek_one(self: *Self) Read_Error!?Data_Type {
                return self.rxi.peek_one();
            }

            pub fn reader(self: *Self) Reader {
                return .{ .context = &self.rxi };
            }

            pub fn reader_nonblocking(self: *Self) Reader_Nonblocking {
                return .{ .context = &self.rxi };
            }

            pub inline fn is_tx_idle(self: *Self) bool {
                return self.txi.is_idle();
            }

            pub inline fn get_tx_available_count(self: *Self) usize {
                return self.txi.get_available_count();
            }

            pub inline fn can_write(self: *Self) bool {
                return self.txi.get_available_count() > 0;
            }

            pub fn writer(self: *Self) Writer {
                return .{ .context = &self.txi };
            }

            pub fn writer_nonblocking(self: *Self) Writer_Nonblocking {
                return .{ .context = &self.txi };
            }

            pub fn handle_interrupt(self: *Self) void {
                const status = periph.interrupt_status_masked.read();
                self.rxi.handle_interrupt(status);
                self.txi.handle_interrupt(status);
            }

        };
    };
}

fn No_Rx(comptime Data_Type: type) type {
    return struct {
        const Self = @This();

        pub fn init(_: Self) void {}
        pub fn deinit(_: Self) void {}
        pub fn start(_: Self) void {}
        pub fn stop(_: Self) void {}

        pub fn get_available_count(_: Self) usize {
            return 0;
        }

        pub fn peek(_: Self, _: []Data_Type) ![]const Data_Type {
            return error.Unimplemented;
        }
        pub fn peek_one(_: Self) !?Data_Type {
            return error.Unimplemented;
        }

        pub fn read_blocking(_: *Self, _: []Data_Type) !usize {
            return error.Unimplemented;
        }

        pub fn read_nonblocking(_: *Self, _: []Data_Type) !usize {
            return error.Unimplemented;
        }

        pub fn handle_interrupt(_: Self, _: reg_types.uart.Interrupt_Bitmap) void {}
    };
}

fn No_Tx(comptime Data_Type: type) type {
    return struct {
        const Self = @This();

        pub fn init(_: Self) void {}
        pub fn deinit(_: Self) void {}
        pub fn start(_: Self) void {}
        pub fn stop(_: Self) void {}

        pub fn is_idle(_: Self) bool {
            return true;
        }

        pub fn get_available_count(_: Self) usize {
            return 0;
        }

        pub fn write_blocking(_: *Self, _: []const Data_Type) !usize {
            return error.Unimplemented;
        }

        pub fn write_nonblocking(_: *Self, _: []const Data_Type) !usize {
            return error.Unimplemented;
        }

        pub fn handle_interrupt(_: Self, _: reg_types.uart.Interrupt_Bitmap) void {}
    };
}

fn Unbuffered_Rx(comptime Data_Type: type, comptime periph: *volatile reg_types.uart.UART, comptime Read_Error: type) type {
    const check_parity = util.error_set_contains_any(Read_Error, error {Parity_Error});

    return struct {
        peek_data: ?Data_Type = null,
        pending_error: Read_Error_Bitmap = .{},

        const Self = @This();

        pub fn init(_: *const Self) void {}
        pub fn deinit(_: *const Self) void {}
        pub fn start(_: *const Self) void {}
        pub fn stop(_: *const Self) void {}

        pub fn get_available_count(self: *const Self) usize {
            if (self.peek_data) |_| return 1;
            if (0 != @as(u4, @bitCast(self.pending_error))) return 1;
            if (!periph.flags.read().rx_fifo_empty) return 1;
            return 0;
        }

        pub fn peek(self: *Self, out: []u8) ![]const Data_Type {
            if (out.len == 0) return out[0..0];

            if (try self.peek_one()) |b| {
                out[0] = b;
                return out[0..1];
            } else {
                return out[0..0];
            }
        }

        pub fn peek_one(self: *Self) !?Data_Type {
            if (0 != @as(u4, @bitCast(self.pending_error))) {
                if (self.pending_error.overrun) return error.Overrun;
                if (self.pending_error.framing_error) return error.Framing_Error;
                if (self.pending_error.break_error) return error.Break_Interrupt;
                if (check_parity and self.pending_error.parity_error) return error.Parity_Error;
            }

            if (self.peek_data) |b| return b;

            if (periph.flags.read().rx_fifo_empty) return null;

            const item = periph.data.read();
            self.pending_error = item.errors;
            if (item.errors.overrun) {
                self.peek_data = @intCast(item.data);
                return error.Overrun;
            } else if (item.errors.framing_error) {
                return error.Framing_Error;
            } else if (item.errors.break_error) {
                return error.Break_Interrupt;
            } else if (check_parity and item.errors.parity_error) {
                return error.Parity_Error;
            } else {
                const data: Data_Type = @intCast(item.data);
                self.peek_data = data;
                return data;
            }
        }

        pub fn read_blocking(self: *Self, buffer: []Data_Type) !usize {
            for (0.., buffer) |i, *out| {
                const result = self.peek_one() catch |err| {
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

                    out.* = (self.peek_one() catch |err| {
                        if (i > 0) return i;

                        if (err == error.Overrun) {
                            self.pending_error.overrun = false;
                        } else {
                            self.pending_error = .{};
                        }
                        return err;
                    }).?;
                }

                self.peek_data = null;
            }

            return buffer.len;
        }

        pub fn read_nonblocking(self: *Self, buffer: []Data_Type) !usize {
            for (0.., buffer) |i, *out| {
                const result = self.peek_one() catch |err| {
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
                    self.peek_data = null;
                } else if (i > 0) {
                    return i;
                } else {
                    return error.Would_Block;
                }
            }

            return buffer.len;
        }

        pub fn handle_interrupt(_: Self, _: reg_types.uart.Interrupt_Bitmap) void {}
    };
}

fn Unbuffered_Tx(comptime Data_Type: type, comptime periph: *volatile reg_types.uart.UART) type {
    return struct {
        const Self = @This();

        pub fn init(_: Self) void {}
        pub fn deinit(_: Self) void {}
        pub fn start(_: Self) void {}
        pub fn stop(_: Self) void {}

        pub fn is_idle(_: Self) bool {
            return !periph.flags.read().tx_in_progress;
        }

        pub fn get_available_count(_: Self) usize {
            return if (periph.flags.read().tx_fifo_full) 0 else 1;
        }

        pub fn write_blocking(_: *Self, data: []const Data_Type) !usize {
            for (data) |b| {
                while (periph.flags.read().tx_fifo_full) {}
                periph.data.write(.{ .data = b });
            }
            return data.len;
        }

        pub fn write_nonblocking(_: *Self, data: []const Data_Type) !usize {
            for (0.., data) |i, b| {
                if (periph.flags.read().tx_fifo_full) {
                    return if (i > 0) i else error.Would_Block;
                }
                periph.data.write(.{ .data = b });
            }
        }

        pub fn handle_interrupt(_: Self, _: reg_types.uart.Interrupt_Bitmap) void {}
    };
}

const Read_Error_Pack = packed struct (u16) {
    data_bytes: u12 = 0, // after errors chronologically
    errors: Read_Error_Bitmap = .{},

    pub fn hasError(self: Read_Error_Pack) bool {
        return 0 != @as(u4, @bitCast(self.errors));
    }
};

fn Interrupt_Rx(comptime Data_Type: type, comptime periph: *volatile reg_types.uart.UART, comptime buffer_size: usize, comptime Read_Error: type) type {
    const check_parity = util.error_set_contains_all(Read_Error, error{Parity_Error});
    const pack_buffer_size = @max(@min(8, buffer_size), buffer_size / 8);
    const DataFifo = std.fifo.LinearFifo(Data_Type, .{ .Static = buffer_size });
    const PackFifo = std.fifo.LinearFifo(Read_Error_Pack, .{ .Static = pack_buffer_size });

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
            self.enable_interrupt();
        }
        pub fn stop(self: *Self) void {
            self.stopped = true;
            self.disable_interrupt();
        }

        pub fn get_available_count(self: *Self) usize {
            const amount = self.data.readableLength();
            if (amount == 0) {
                return self.packs.readableLength();
            }
            return amount;
        }

        pub fn peek(self: *Self, out: []Data_Type) ![]const Data_Type {
            if (out.len == 0) return out[0..0];

            // Note since we never modify the FIFOs here, we don't need to disable interrupts.
            // If it interrupts us and adds more data it's not a problem.

            var dest_offset: usize = 0;
            outer: for (0..self.packs.readableLength()) |pack_index| {
                const pack: Read_Error_Pack = self.packs.peekItem(pack_index);

                if (pack.hasError()) {
                    if (dest_offset == 0) {
                        if (pack.errors.overrun) return error.Overrun;
                        if (pack.errors.framing_error) return error.Framing_Error;
                        if (pack.errors.break_error) return error.Break_Interrupt;
                        if (check_parity) {
                            if (pack.errors.parity_error) return error.Parity_Error;
                        } else std.debug.assert(!pack.errors.parity_error);
                    } else {
                        break :outer;
                    }
                }

                var num_data_byte: usize = pack.data_bytes;
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

        pub fn peek_one(self: *Self) !?Data_Type {
            var buf: [1]Data_Type = undefined;
            const result = try self.peek(&buf);
            if (result.len > 0) return result[0];
            return null;
        }

        fn check_read_error(self: *Self, errors: Read_Error_Bitmap) !void {
            if (errors.overrun) {
                self.packs.buf[self.packs.head].errors.overrun = false;
                return error.Overrun;
            }
            if (errors.framing_error) {
                self.packs.buf[self.packs.head].errors.framing_error = false;
                return error.Framing_Error;
            }
            if (errors.break_error) {
                self.packs.buf[self.packs.head].errors.break_error = false;
                return error.Break_Interrupt;
            }
            if (check_parity) {
                if (errors.parity_error) {
                    self.packs.buf[self.packs.head].errors.parity_error = false;
                    return error.Parity_Error;
                }
            } else std.debug.assert(!errors.parity_error);
        }

        pub fn read_blocking(self: *Self, out: []Data_Type) Read_Error!usize {
            var remaining = out;
            while (remaining.len > 0) {
                const bytes_read: usize = self.read_nonblocking(remaining) catch |err| switch (err) {
                    error.Would_Block => blk: {
                        while (self.packs.readableLength() == 0) {
                            self.enable_interrupt();
                            interrupts.wait_for_interrupt();
                        }
                        break :blk 0;
                    },
                    else => |e| return e,
                };
                remaining = remaining[bytes_read..];
            }

            return out.len;
        }

        pub fn read_nonblocking(self: *Self, out: []Data_Type) (Read_Error||error{Would_Block})!usize {
            var remaining = out;
            while (remaining.len > 0) {
                if (self.packs.readableLength() == 0) {
                    if (remaining.ptr != out.ptr) break;

                    return error.Would_Block;
                }

                var pack: Read_Error_Pack = self.packs.peekItem(0);

                if (pack.hasError()) {
                    if (remaining.ptr != out.ptr) break;
                    try self.check_read_error(pack.errors);
                    unreachable;
                }

                const bytes_to_read = @min(remaining.len, pack.data_bytes);
                if (bytes_to_read > 0) {
                    var cs = microbe.Critical_Section.enter();
                    const bytes_read = self.data.read(remaining[0..bytes_to_read]);
                    cs.leave();
                    std.debug.assert(bytes_read == bytes_to_read);
                    remaining = remaining[bytes_read..];
                }

                var cs = microbe.Critical_Section.enter();
                pack = self.packs.peekItem(0);
                if (bytes_to_read < pack.data_bytes) {
                    self.packs.buf[self.packs.head].data_bytes = pack.data_bytes - bytes_to_read;
                } else {
                    self.packs.discard(1);
                }
                cs.leave();
                self.enable_interrupt();
            }

            return out.len - remaining.len;
        }

        pub fn enable_interrupt(self: *Self) void {
            if (periph.interrupt_mask.read().rx) return;
            if (self.stopped) return;
            if (self.packs.writableLength() < 2) return;
            if (self.data.writableLength() == 0) return;

            periph.interrupt_mask.set_bits(.{
                .rx = true,
                .rx_timeout = true,
            });
        }

        pub fn disable_interrupt(_: *Self) void {
            periph.interrupt_mask.clear_bits(.{
                .rx = true,
                .rx_timeout = true,
            });
        }

        pub fn handle_interrupt(self: *Self, status: reg_types.uart.Interrupt_Bitmap) void {
            if (status.rx or status.rx_timeout) {
                self.try_process_interrupt_data();
            }
        }

        fn try_process_interrupt_data(self: *Self) void {
            const writable_len = self.data.writableLength();
            if (writable_len == 0 or self.packs.writableLength() < 2) {
                self.disable_interrupt();
                return;
            }

            var buf: [32]Data_Type = undefined;
            const max_read_count = @min(buf.len, writable_len);
            var read_count: u12 = 0;

            const errors: Read_Error_Bitmap = for (0..max_read_count) |i| {
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
            self.record_pack_data_bytes(read_count);

            if (0 != @as(u4, @bitCast(errors))) {
                self.packs.writeItemAssumeCapacity(.{
                    .data_bytes = 0,
                    .errors = errors,
                });
                if (errors.overrun) {
                    self.data.writeAssumeCapacity(buf[read_count..][0..1]);
                    self.record_pack_data_bytes(1);
                }
            }
        }

        fn record_pack_data_bytes(self: *Self, count: u12) void {
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

fn Interrupt_Tx(comptime Data_Type: type, comptime periph: *volatile reg_types.uart.UART, comptime buffer_size: usize) type {
    const Fifo = std.fifo.LinearFifo(Data_Type, .{ .Static = buffer_size });

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
            self.enable_interrupt();
        }
        pub fn stop(self: *Self) void {
            self.stopped = true;
            self.disable_interrupt();
        }

        pub fn is_idle(self: *Self) bool {
            return !periph.flags.read().tx_in_progress and self.data.readableLength() == 0;
        }

        pub fn get_available_count(self: *Self) usize {
            return self.data.writableLength();
        }

        pub fn write_blocking(self: *Self, data_to_write: []const Data_Type) !usize {
            if (data_to_write.len == 0) return 0;

            var remaining = self.write_direct(data_to_write);
            while (remaining.len > 0) {
                var bytes_to_write = self.data.writableLength();
                while (bytes_to_write == 0) {
                    self.enable_interrupt();
                    interrupts.wait_for_interrupt();
                    bytes_to_write = self.data.writableLength();
                }

                if (bytes_to_write > remaining.len) {
                    bytes_to_write = remaining.len;
                }

                var cs = microbe.Critical_Section.enter();
                self.data.writeAssumeCapacity(remaining[0..bytes_to_write]);
                cs.leave();
                remaining = remaining[bytes_to_write..];

                self.enable_interrupt();
            }

            return data_to_write.len;
        }

        pub fn write_nonblocking(self: *Self, data_to_write: []const Data_Type) !usize {
            if (data_to_write.len == 0) return 0;

            const remaining = self.write_direct(data_to_write);
            if (remaining.len == 0) return data_to_write.len;

            const bytes_to_write = @min(self.data.writableLength(), remaining.len);
            if (bytes_to_write == 0) {
                if (remaining.len == data_to_write.len) {
                    return error.Would_Block;
                } else {
                    return data_to_write.len - remaining.len;
                }
            }

            var cs = microbe.Critical_Section.enter();
            self.data.writeAssumeCapacity(remaining[0..bytes_to_write]);
            cs.leave();
            self.enable_interrupt();
            return data_to_write.len - remaining.len + bytes_to_write;
        }

        fn write_direct(self: *Self, data_to_write: []const Data_Type) []const Data_Type {
            var remaining = data_to_write;
            if (self.data.readableLength() == 0) {
                var cs = microbe.Critical_Section.enter();
                defer cs.leave();
                while (remaining.len > 0 and !periph.flags.read().tx_fifo_full) {
                    periph.data.write(.{ .data = remaining[0] });
                    remaining = remaining[1..];
                }
            }
            return remaining;
        }

        pub fn enable_interrupt(self: *Self) void {
            if (periph.interrupt_mask.read().tx) return;
            if (self.stopped) return;
            if (self.data.readableLength() == 0) return;

            periph.interrupt_mask.set_bits(.tx);
        }

        pub fn disable_interrupt(_: *Self) void {
            periph.interrupt_mask.clear_bits(.tx);
        }

        pub fn handle_interrupt(self: *Self, status: reg_types.uart.Interrupt_Bitmap) void {
            if (status.tx) {
                self.try_process_interrupt_data();
            }
        }

        pub fn try_process_interrupt_data(self: *Self) void {
            const readable = self.data.readableSlice(0);
            var bytes_written: usize = 0;
            for (readable) |b| {
                if (periph.flags.read().tx_fifo_full) break;
                periph.data.write(.{ .data = b });
                bytes_written += 1;
            }
            self.data.discard(bytes_written);

            if (self.data.readableLength() == 0) {
                self.disable_interrupt();
            }
        }

    };
}

fn DMA_Rx(comptime Data_Type: type, comptime periph: *volatile reg_types.uart.UART, comptime buffer_size: usize, comptime channel: dma.Channel) type {
    _ = Data_Type; // autofix
    _ = periph; // autofix
    _ = buffer_size; // autofix
    _ = channel; // autofix
    @compileError("Not implemented yet");
}

fn DMA_Tx(comptime Data_Type: type, comptime periph: *volatile reg_types.uart.UART, comptime buffer_size: usize, comptime channel: dma.Channel) type {
    _ = Data_Type; // autofix
    _ = periph; // autofix
    _ = buffer_size; // autofix
    _ = channel; // autofix
    @compileError("Not implemented yet");
}

const dma = @import("dma.zig");
const clocks = @import("clocks.zig");
const resets = @import("resets.zig");
const validation = @import("validation.zig");
const peripherals = @import("peripherals.zig");
const interrupts = @import("interrupts.zig");
const gpio = @import("gpio.zig");
const Read_Error_Bitmap = reg_types.uart.Read_Error_Bitmap;
const reg_types = @import("reg_types.zig");
const Pad_ID = chip.Pad_ID;
const chip = @import("../rp2040.zig");
const util = microbe.util;
const microbe = @import("microbe");
const std = @import("std");
