pub const Data_Bits = reg_types.spi.Data_Bits;
pub const Format = reg_types.spi.Format;

pub const Controller_Config = struct {
    name: [*:0]const u8 = "SPI",
    clocks: clocks.Parsed_Config = clocks.get_config(),
    format: Format,
    bit_rate: comptime_int,
    data_bits: Data_Bits = .eight,
    sck: Pad_ID,
    tx: ?Pad_ID,
    rx: ?Pad_ID,
    cs: ?Pad_ID = null,
    out_config: gpio.Config = .{
        .speed = .fast,
        .strength = .@"4mA",
        .output_disabled = false,
    },
    in_config: gpio.Config = .{
        .hysteresis = false,
        .maintenance = .pull_up,
        .input_enabled = true,
    },
    tx_buffer_size: comptime_int = 0,
    rx_buffer_size: comptime_int = 0,
    tx_dma_channel: ?dma.Channel = null,
    rx_dma_channel: ?dma.Channel = null,
};

pub fn Controller(comptime config: Controller_Config) type {
    return comptime blk: {
        var want_spi0 = false;
        var want_spi1 = false;
        var want_dma = false;

        var pads: []const Pad_ID = &.{};
        var output_pads: []const Pad_ID = &.{};
        var input_pads: []const Pad_ID = &.{};

        switch (config.sck) {
            .GPIO2, .GPIO6, .GPIO18, .GPIO22 => want_spi0 = true,
            .GPIO10, .GPIO14, .GPIO26 => want_spi1 = true,
            else => @compileError("Invalid SCK pad ID"),
        }
        pads = pads ++ [_]Pad_ID{config.sck};
        output_pads = output_pads ++ [_]Pad_ID{config.sck};
        validation.pads.reserve(config.sck, config.name ++ ".SCK");

        if (config.tx) |tx| {
            switch (tx) {
                .GPIO3, .GPIO7, .GPIO19, .GPIO23 => want_spi0 = true,
                .GPIO11, .GPIO15, .GPIO27 => want_spi1 = true,
                else => @compileError("Invalid TX pad ID"),
            }
            pads = pads ++ [_]Pad_ID{tx};
            output_pads = output_pads ++ [_]Pad_ID{tx};
            validation.pads.reserve(tx, config.name ++ ".TX");

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
                .GPIO0, .GPIO4, .GPIO16, .GPIO20 => want_spi0 = true,
                .GPIO8, .GPIO12, .GPIO24, .GPIO28 => want_spi1 = true,
                else => @compileError("Invalid RX pad ID"),
            }
            pads = pads ++ [_]Pad_ID{rx};
            input_pads = input_pads ++ [_]Pad_ID{rx};
            validation.pads.reserve(rx, config.name ++ ".RX");

            if (config.rx_dma_channel) |_| {
                want_dma = true;
            }
        } else if (config.rx_dma_channel) |_| {
            @compileError("RX pad not specified!");
        } else if (config.rx_buffer_size > 0) |_| {
            @compileError("RX pad not specified!");
        }

        if (config.cs) |cs| {
            switch (cs) {
                .GPIO1, .GPIO5, .GPIO17, .GPIO21 => want_spi0 = true,
                .GPIO9, .GPIO13, .GPIO25, .GPIO29 => want_spi1 = true,
                else => @compileError("Invalid CS pad ID"),
            }
            pads = pads ++ [_]Pad_ID{cs};
            output_pads = input_pads ++ [_]Pad_ID{cs};
            validation.pads.reserve(cs, config.name ++ ".CS");
        }

        if (want_spi0 and want_spi1) {
            @compileError("All pads must be associated with the same SPI interface");
        }

        if (!want_spi0 and !want_spi1) {
            @compileError("SPI without TX or RX is useless!");
        }

        if (config.rx_dma_channel != null and std.meta.eql(config.rx_dma_channel, config.tx_dma_channel)) {
            @compileError("RX and TX may not use the same DMA channel");
        }

        if (config.clocks.uart_spi.frequency_hz == 0) {
            @compileError("SPI clock not configured!");
        }

        if (config.bit_rate == 0) {
            @compileError("Bit rate too low!");
        }

        // Glossary for PrimeCell documentation
        // PCLK == config.clocks.sys
        // SSPCLK = config.clocks.uart_spi
        // SSPTXINTR = Interrupt_Bitmap.tx_fifo
        // SSPRXINTR = Interrupt_Bitmap.rx_fifo
        // SSPRORINTR = Interrupt_Bitmap.rx_overrun
        // SSPRTINTR = Interrupt_Bitmap.rx_timeout
        // SSPFSSOUT = CS
        // nSSPOE is disconnected internally

        const spi_clk = config.clocks.uart_spi.frequency_hz;
        if (spi_clk > config.clocks.sys.frequency_hz) {
            @compileError(std.fmt.comptimePrint("System clock must be at least {} for SPI clock of {}", .{
                util.fmt_frequency(spi_clk),
                util.fmt_frequency(spi_clk),
            }));
        }

        var best: ?struct {
            prescale: comptime_int,
            divisor: comptime_int,
            actual_bit_rate: comptime_int,
        } = null;

        for (1..128) |p| {
            const prescale = 256 - 2 * p;
            const prescaled_frequency_hz = util.div_round(spi_clk, prescale);
            const divisor = std.math.clamp(util.div_round(prescaled_frequency_hz, config.bit_rate), 1, 256);
            const actual_bit_rate = util.div_round(spi_clk, prescale * divisor);

            if (best) |prev| {
                const new_error = @abs(actual_bit_rate - config.bit_rate);
                const old_error = @abs(prev.actual_bit_rate - config.bit_rate);
                if (new_error >= old_error) continue;
            }
            
            best = .{
                .prescale = prescale,
                .divisor = divisor,
                .actual_bit_rate = actual_bit_rate,
            };

            if (actual_bit_rate == config.bit_rate) break;
        }

        const clk = best.?;

        if (clk.actual_bit_rate != config.bit_rate) {
            @compileError(std.fmt.comptimePrint("Cannot achieve bit rate {}; closest possible is {}", .{
                config.bit_rate,
                clk.actual_bit_rate,
            }));
        }

        const periph: *volatile reg_types.spi.SPI = if (want_spi0) peripherals.SPI0 else peripherals.SPI1;

        const Data = switch (config.data_bits) {
            .four => u4,
            .five => u5,
            .six => u6,
            .seven => u7,
            .eight => u8,
            .nine => u9,
            .ten => u10,
            .eleven => u11,
            .twelve => u12,
            .thirteen => u13,
            .fourteen => u14,
            .fifteen => u15,
            .sixteen => u16,
            else => unreachable,
        };

        const Errors = struct {
            const Read             = if (config.rx == null) error { Unimplemented } else error {};
            const Read_Nonblocking = if (config.rx == null) error { Unimplemented } else error{ Would_Block };

            const Write             = if (config.tx == null) error { Unimplemented } else error {};
            const Write_Nonblocking = if (config.tx == null) error { Unimplemented } else error { Would_Block };
        };

        const Rx = rx: {
            if (config.rx == null) {
                break :rx No_Rx(Data);
            } else if (config.rx_buffer_size == 0) {
                break :rx Unbuffered_Rx(Data, periph);
            } else if (config.rx_dma_channel) |channel| {
                break :rx DMA_Rx(Data, periph, config.rx_buffer_size, channel);
            } else {
                break :rx Interrupt_Rx(Data, periph, config.rx_buffer_size);
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
                    if (want_spi0) resets.reset(.spi0);
                    if (want_spi1) resets.reset(.spi1);
                }

                periph.control1.write(.{ .enabled = false });

                gpio.set_function_all(pads, .spi);
                gpio.configure(output_pads, config.out_config);
                gpio.configure(input_pads, config.in_config);

                periph.clock_prescale.write(.{
                    .divisor = clk.prescale,
                });

                periph.control0.write(.{
                    .data_bits = config.data_bits,
                    .format = config.format,
                    .clock_rate_factor = clk.divisor - 1,
                });

                periph.control1.write(.{
                    .role = .controller,
                });

                if (config.tx_buffer_size > 0 or config.rx_buffer_size > 0) {
                    if (want_spi0) {
                        peripherals.NVIC.interrupt_clear_pending.write(.{ .SPI0_IRQ = true });
                        peripherals.NVIC.interrupt_set_enable.write(.{ .SPI0_IRQ = true });
                    } else {
                        peripherals.NVIC.interrupt_clear_pending.write(.{ .SPI1_IRQ = true });
                        peripherals.NVIC.interrupt_set_enable.write(.{ .SPI1_IRQ = true });
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
                periph.control1.modify(.{ .enabled = true });
            }

            pub fn stop(self: *Self) void {
                self.txi.stop();
                self.rxi.stop();
                while (!self.txi.is_idle()) {}
                periph.control1.modify(.{ .enabled = false });
            }

            pub fn deinit(self: *Self) void {
                self.txi.deinit();
                self.rxi.deinit();

                periph.control1.modify(.{ .enabled = false });

                gpio.set_function_all(pads, .disable);

                if (want_spi0) resets.hold_in_reset(.spi0);
                if (want_spi1) resets.hold_in_reset(.spi1);
            }

            pub fn get_rx_available_count(self: *Self) usize {
                return self.rxi.get_available_count();
            }

            pub fn can_read(self: *Self) bool {
                return self.rxi.get_available_count() > 0;
            }

            pub fn peek(self: *Self, buffer: []Data_Type) Read_Error![]const Data_Type {
                return self.rxi.peek(buffer);
            }

            pub fn peek_one(self: *Self) Read_Error!?Data_Type {
                return @call(.always_inline, self.rxi.peek_one, .{});
            }

            pub fn reader(self: *Self) Reader {
                return .{ .context = &self.rxi };
            }

            pub fn reader_nonblocking(self: *Self) Reader_Nonblocking {
                return .{ .context = &self.rxi };
            }

            pub fn is_tx_idle(self: *Self) bool {
                return self.txi.is_idle();
            }

            pub fn get_tx_available_count(self: *Self) usize {
                return self.txi.get_available_count();
            }

            pub fn can_write(self: *Self) bool {
                return self.txi.get_available_count() > 0;
            }

            pub fn writer(self: *Self) Writer {
                return .{ .context = &self.txi };
            }

            pub fn writer_nonblocking(self: *Self) Writer_Nonblocking {
                return .{ .context = &self.txi };
            }

            pub fn handle_interrupt(self: *Self) void {
                const status = periph.irq.status.read();
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

        pub fn handle_interrupt(_: Self, _: reg_types.spi.Interrupt_Bitmap) void {}
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

        pub fn handle_interrupt(_: Self, _: reg_types.spi.Interrupt_Bitmap) void {}
    };
}

fn Unbuffered_Rx(comptime Data_Type: type, comptime periph: *volatile reg_types.spi.SPI) type {
    return struct {
        peek_data: ?Data_Type = null,

        const Self = @This();

        pub fn init(_: *const Self) void {}
        pub fn deinit(_: *const Self) void {}
        pub fn start(_: *const Self) void {}
        pub fn stop(_: *const Self) void {}

        pub fn get_available_count(self: *const Self) usize {
            if (self.peek_data) |_| return 1;
            return if (fifo_empty()) 0 else 1;
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
            if (self.peek_data) |b| return b;
            if (fifo_empty()) return null;

            const data: Data_Type = @intCast(periph.fifo.read().data);
            self.peek_data = data;
            return data;
        }

        pub fn read_blocking(self: *Self, buffer: []Data_Type) !usize {
            if (buffer.len == 0) return 0;

            buffer[0] = if (try self.peek_one()) |b| b else blk: {
                while (fifo_empty()) {}
                break :blk @intCast(periph.fifo.read().data);
            };
            self.peek_data = null;

            for (buffer[1..]) |*out| {
                while (fifo_empty()) {}
                out.* = @intCast(periph.fifo.read().data);
            }

            return buffer.len;
        }

        pub fn read_nonblocking(self: *Self, buffer: []Data_Type) !usize {
            if (buffer.len == 0) return 0;

            if (try self.peek_one()) |b| {
                buffer[0] = b;
                self.peek_data = null;
            } else {
                return error.Would_Block;
            }

            for (1.., buffer[1..]) |i, *out| {
                if (fifo_empty()) {
                    return i;
                } else {
                    out.* = @intCast(periph.fifo.read().data);
                }
            }

            return buffer.len;
        }

        inline fn fifo_empty() bool {
            return !periph.status.read().rx_fifo_not_empty;
        }

        pub fn handle_interrupt(_: Self, _: reg_types.spi.Interrupt_Bitmap) void {}
    };
}

fn Unbuffered_Tx(comptime Data_Type: type, comptime periph: *volatile reg_types.spi.SPI) type {
    return struct {
        const Self = @This();

        pub fn init(_: Self) void {}
        pub fn deinit(_: Self) void {}
        pub fn start(_: Self) void {}
        pub fn stop(_: Self) void {}

        pub fn is_idle(_: Self) bool {
            return !periph.status.read().transfer_in_progress;
        }

        pub fn get_available_count(_: Self) usize {
            return if (fifo_full()) 0 else 1;
        }

        pub fn write_blocking(_: *Self, data: []const Data_Type) !usize {
            for (data) |b| {
                while (fifo_full()) {}
                periph.fifo.write(.{ .data = b });
            }
            return data.len;
        }

        pub fn write_nonblocking(_: *Self, data: []const Data_Type) !usize {
            for (0.., data) |i, b| {
                if (fifo_full()) {
                    return if (i > 0) i else error.Would_Block;
                }
                periph.fifo.write(.{ .data = b });
            }
        }

        inline fn fifo_full() bool {
            return !periph.status.read().tx_fifo_not_full;
        }

        pub fn handle_interrupt(_: Self, _: reg_types.spi.Interrupt_Bitmap) void {}
    };
}

fn Interrupt_Rx(comptime Data_Type: type, comptime periph: *volatile reg_types.spi.SPI, comptime buffer_size: usize) type {
    const DataFifo = std.fifo.LinearFifo(Data_Type, .{ .Static = buffer_size });

    if (!std.math.isPowerOfTwo(buffer_size)) {
        @compileError("SPI buffer size must be a power of two!");
    }

    return struct {
        data: DataFifo = undefined,
        stopped: bool = true,

        const Self = @This();

        pub fn init(self: *Self) void {
            self.data = DataFifo.init();
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

        pub fn get_available_count(self: *Self) usize {
            return self.data.readableLength();
        }

        pub fn peek(self: *Self, out: []Data_Type) ![]const Data_Type {
            if (out.len == 0) return out[0..0];

            // Note since we never modify the FIFOs here, we don't need to disable interrupts.
            // If it interrupts us and adds more data it's not a problem.

            const bytes = self.data.readableSlice(0);
            if (bytes.len >= out.len) {
                @memcpy(out, bytes.ptr);
                return out;
            } else {
                @memcpy(out.ptr, bytes);
                const additional_bytes = self.data.readableSlice(bytes.len);
                if (bytes.len + additional_bytes.len >= out.len) {
                    @memcpy(out[bytes.len..], additional_bytes.ptr);
                    return out;
                } else {
                    @memcpy(out[bytes.len..].ptr, additional_bytes);
                    return out[0 .. bytes.len + additional_bytes.len];
                }
            }
        }

        pub fn peek_one(self: *Self) !?Data_Type {
            var buf: [1]Data_Type = undefined;
            const result = try self.peek(&buf);
            if (result.len > 0) return result[0];
            return null;
        }

        pub fn read_blocking(self: *Self, out: []Data_Type) !usize {
            var remaining = out;
            while (remaining.len > 0) {
                const bytes_read: usize = self.read_nonblocking(remaining) catch |err| switch (err) {
                    error.Would_Block => blk: {
                        while (self.data.readableLength() == 0) {
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

        pub fn read_nonblocking(self: *Self, out: []Data_Type) error{Would_Block}!usize {
            var remaining = out;
            while (remaining.len > 0) {
                const bytes_to_read = @min(remaining.len, self.data.readableLength());
                if (bytes_to_read == 0) {
                    if (remaining.ptr != out.ptr) break;
                    return error.Would_Block;
                }
                var cs = microbe.Critical_Section.enter();
                const bytes_read = self.data.read(remaining[0..bytes_to_read]);
                cs.leave();
                std.debug.assert(bytes_read == bytes_to_read);
                remaining = remaining[bytes_read..];
                self.enable_interrupt();
            }
            return out.len - remaining.len;
        }

        pub fn enable_interrupt(self: *Self) void {
            if (periph.irq.enable.read().rx_fifo) return;
            if (self.stopped) return;
            if (self.data.writableLength() == 0) return;

            periph.irq.enable.set_bits(.{
                .rx_fifo = true,
                .rx_timeout = true,
            });
        }

        pub fn disable_interrupt(_: *Self) void {
            periph.irq.enable.clear_bits(.{
                .rx_fifo = true,
                .rx_timeout = true,
            });
        }

        pub fn handle_interrupt(self: *Self, status: reg_types.spi.Interrupt_Bitmap) void {
            if (status.rx_fifo or status.rx_timeout) {
                self.try_process_interrupt_data();
            }
        }

        fn try_process_interrupt_data(self: *Self) void {
            const writable_len = self.data.writableLength();
            if (writable_len == 0) {
                self.disable_interrupt();
                return;
            }

            var buf: [8]Data_Type = undefined;
            const max_read_count = @min(buf.len, writable_len);
            var read_count: u12 = 0;

            while (read_count < max_read_count) {
                if (fifo_empty()) {
                    periph.irq.clear.write(.{ .rx_timeout = true });
                    break;
                }
                buf[read_count] = @intCast(periph.fifo.read().data);
                read_count += 1;
            }

            self.data.writeAssumeCapacity(buf[0..read_count]);
        }

        inline fn fifo_empty() bool {
            return !periph.status.read().rx_fifo_not_empty;
        }
    };
}

fn Interrupt_Tx(comptime Data_Type: type, comptime periph: *volatile reg_types.spi.SPI, comptime buffer_size: usize) type {
    const Fifo = std.fifo.LinearFifo(Data_Type, .{ .Static = buffer_size });

    if (!std.math.isPowerOfTwo(buffer_size)) {
        @compileError("SPI buffer size must be a power of two!");
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
            return !periph.status.read().transfer_in_progress and self.data.readableLength() == 0;
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
                while (remaining.len > 0 and !fifo_full()) {
                    periph.fifo.write(.{ .data = remaining[0] });
                    remaining = remaining[1..];
                }
            }
            return remaining;
        }

        pub fn enable_interrupt(self: *Self) void {
            if (periph.irq.enable.read().tx_fifo) return;
            if (self.stopped) return;
            if (self.data.readableLength() == 0) return;

            periph.irq.enable.set_bits(.tx_fifo);
        }

        pub fn disable_interrupt(_: *Self) void {
            periph.irq.enable.clear_bits(.tx_fifo);
        }

        pub fn handle_interrupt(self: *Self, status: reg_types.spi.Interrupt_Bitmap) void {
            if (status.tx_fifo) {
                self.try_process_interrupt_data();
            }
        }

        pub fn try_process_interrupt_data(self: *Self) void {
            const readable = self.data.readableSlice(0);
            var bytes_written: usize = 0;
            for (readable) |b| {
                if (fifo_full()) break;
                periph.fifo.write(.{ .data = b });
                bytes_written += 1;
            }
            self.data.discard(bytes_written);

            if (self.data.readableLength() == 0) {
                self.disable_interrupt();
            }
        }

        inline fn fifo_full() bool {
            return !periph.status.read().tx_fifo_not_full;
        }

    };
}

fn DMA_Rx(comptime Data_Type: type, comptime periph: *volatile reg_types.spi.SPI, comptime buffer_size: usize, comptime channel: dma.Channel) type {
    _ = Data_Type; // autofix
    _ = periph; // autofix
    _ = buffer_size; // autofix
    _ = channel; // autofix
    @compileError("Not implemented yet");
}

fn DMA_Tx(comptime Data_Type: type, comptime periph: *volatile reg_types.spi.SPI, comptime buffer_size: usize, comptime channel: dma.Channel) type {
    _ = Data_Type; // autofix
    _ = periph; // autofix
    _ = buffer_size; // autofix
    _ = channel; // autofix
    @compileError("Not implemented yet");
}

const dma = chip.dma;
const clocks = chip.clocks;
const resets = chip.resets;
const validation = chip.validation;
const peripherals = chip.peripherals;
const interrupts = chip.interrupts;
const gpio = chip.gpio;
const reg_types = chip.reg_types;
const Pad_ID = chip.Pad_ID;
const chip = @import("chip");
const util = microbe.util;
const microbe = @import("microbe");
const std = @import("std");
