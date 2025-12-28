//! Asynchronous JTAG controller using one PIO state machine:
//! * TCK, TMS, TDI, TDO all on independent GPIOs
//! * JTAG TCK frequency == approx. sysclk / 16
//! * Intended for use with a non-blocking main loop
//!     * Sending commands and reading data from TDO never blocks
//!     * PIO FIFO servicing happens from main loop

pub const State = enum (u8) {
    unknown = 0x10,
    reset = 0x11,
    idle = 0x12,
    dr_select = 0x1,
    dr_capture = 0x2,
    dr_shift = 0x3,
    dr_exit1 = 0x4,
    dr_pause = 0x5,
    dr_exit2 = 0x6,
    dr_update = 0x7,
    ir_select = 0x9,
    ir_capture = 0xA,
    ir_shift = 0xB,
    ir_exit1 = 0xC,
    ir_pause = 0xD,
    ir_exit2 = 0xE,
    ir_update = 0xF,

    pub fn is_dr(self: State) bool {
        return (@intFromEnum(self) & 0xF8) == 0;
    }

    pub fn is_ir(self: State) bool {
        return (@intFromEnum(self) & 0xF8) == 8;
    }
};

pub fn Builder(comptime buffer_len: comptime_int) type {
    return struct {
        buffer: [buffer_len]u32,
        len: u16,
        current_state: State,
        wip_delay: u10,
        wip_count: u6,
        wip_bits: [16]Out_Bits_4,
        wip_push_isr: bool,

        pub fn init(initial_state: State) @This() {
            return .{
                .buffer = @splat(0),
                .len = 0,
                .current_state = initial_state,
                .wip_delay = 0,
                .wip_count = 0,
                .wip_bits = @splat(.zero),
                .wip_push_isr = false,
            };
        }

        pub fn apply(self: *@This(), jtag: anytype) !void {
            if (@typeInfo(@TypeOf(jtag)) != .pointer) {
                @compileError("JTAG interface must be passed by pointer"); 
            }
            try self.flush();
            if (jtag.out.available() < self.len) return error.InsufficientSpace;
            for (self.buffer[0..self.len]) |word| {
                jtag.out.push(word) catch unreachable;
            }
            jtag.state = self.current_state;
            self.len = 0;
        }

        pub fn delay(self: *@This(), cycles: u32) !void {
            if (self.wip_count > 0) try self.flush();
            var new_wip_delay: u32 = cycles + self.wip_delay;
            while (new_wip_delay > std.math.maxInt(u10)) {
                try self.push(@bitCast(Command {
                    .delay = std.math.maxInt(u10),
                    .bits = 0,
                }));
                new_wip_delay -= std.math.maxInt(u10);
            }
            self.wip_delay = @intCast(new_wip_delay);
        }

        pub fn state(self: *@This(), new_state: State) !void {
            if (self.current_state == new_state or new_state == .unknown) return;
            if (self.wip_push_isr) {
                try self.flush();
                self.wip_push_isr = false;
            }
            while (self.current_state != new_state) {
                switch (self.current_state) {
                    .unknown => {
                        try self.append(.{ .tms = 1 });
                        try self.append(.{ .tms = 1 });
                        try self.append(.{ .tms = 1 });
                        try self.append(.{ .tms = 1 });
                        try self.append(.{ .tms = 1 });
                        self.current_state = .reset;
                    },
                    .reset => {
                        try self.append(.{ .tms = 0 });
                        self.current_state = .idle;
                    },
                    .idle => {
                        try self.append(.{ .tms = 1 });
                        self.current_state = .dr_select;
                    },
                    .dr_select => {
                        if (new_state.is_dr()) {
                            try self.append(.{ .tms = 0 });
                            self.current_state = .dr_capture;
                        } else {
                            try self.append(.{ .tms = 1 });
                            self.current_state = .ir_select;
                        }
                    },
                    .dr_capture => {
                        if (new_state == .dr_shift) {
                            try self.append(.{ .tms = 0 });
                            self.current_state = .dr_shift;
                        } else {
                            try self.append(.{ .tms = 1 });
                            self.current_state = .dr_exit1;
                        }
                    },
                    .dr_shift => {
                        try self.append(.{ .tms = 1 });
                        self.current_state = .dr_exit1;
                    },
                    .dr_exit1 => switch (new_state) {
                        .dr_shift, .dr_pause, .dr_exit2 => {
                            try self.append(.{ .tms = 0 });
                            self.current_state = .dr_pause;
                        },
                        else => {
                            try self.append(.{ .tms = 1 });
                            self.current_state = .dr_update;
                        },
                    },
                    .dr_pause => {
                        try self.append(.{ .tms = 1 });
                        self.current_state = .dr_exit2;
                    },
                    .dr_exit2 => {
                        if (new_state == .dr_shift) {
                            try self.append(.{ .tms = 0 });
                            self.current_state = .dr_shift;
                        } else {
                            try self.append(.{ .tms = 1 });
                            self.current_state = .dr_update;
                        }
                    },
                    .dr_update, .ir_update => {
                        if (new_state == .idle) {
                            try self.append(.{ .tms = 0 });
                            self.current_state = .idle;
                        } else {
                            try self.append(.{ .tms = 1 });
                            self.current_state = .dr_select;
                        }
                    },
                    .ir_select => {
                        if (new_state.is_ir()) {
                            try self.append(.{ .tms = 0 });
                            self.current_state = .ir_capture;
                        } else {
                            try self.append(.{ .tms = 1 });
                            self.current_state = .reset;
                        }
                    },
                    .ir_capture => {
                        if (new_state == .ir_shift) {
                            try self.append(.{ .tms = 0 });
                            self.current_state = .ir_shift;
                        } else {
                            try self.append(.{ .tms = 1 });
                            self.current_state = .ir_exit1;
                        }
                    },
                    .ir_shift => {
                        try self.append(.{ .tms = 1 });
                        self.current_state = .ir_exit1;
                    },
                    .ir_exit1 => switch (new_state) {
                        .ir_shift, .ir_pause, .ir_exit2 => {
                            try self.append(.{ .tms = 0 });
                            self.current_state = .ir_pause;
                        },
                        else => {
                            try self.append(.{ .tms = 1 });
                            self.current_state = .ir_update;
                        },
                    },
                    .ir_pause => {
                        try self.append(.{ .tms = 1 });
                        self.current_state = .ir_exit2;
                    },
                    .ir_exit2 => {
                        if (new_state == .ir_shift) {
                            try self.append(.{ .tms = 0 });
                            self.current_state = .ir_shift;
                        } else {
                            try self.append(.{ .tms = 1 });
                            self.current_state = .ir_update;
                        }
                    },
                }
            }
        }

        pub fn shift(self: *@This(), comptime T: type, value: T, with_input: bool) !void {
            std.debug.assert(self.current_state == .ir_shift or self.current_state == .dr_shift);
            if (self.wip_bits > 0 and self.wip_push_isr != with_input) {
                try self.flush();
            }
            self.wip_push_isr = with_input;
            const Int = std.meta.Int(.unsigned, @bitSizeOf(T));
            var bits_remaining: u32 = @bitSizeOf(T);
            var value_remaining = util.to_int(Int, value);
            while (bits_remaining > 1) : (bits_remaining -= 1) {
                try self.append(.{ .tms = 0, .tdi = @truncate(value_remaining) });
                value_remaining >>= 1;
            }
            try self.append(.{ .tms = 1, .tdi = @truncate(value_remaining) });
            self.current_state = switch (self.current_state) {
                .ir_shift => .ir_exit1,
                .dr_shift => .dr_exit1,
            };
        }

        pub fn ir_out(self: *@This(), comptime T: type, value: T) !void {
            self.state(.ir_shift);
            self.shift(T, value, false);
        }

        pub fn dr_out(self: *@This(), comptime T: type, value: T) !void {
            self.state(.dr_shift);
            self.shift(T, value, false);
        }

        /// N.B. Since actual JTAG I/O is asynchronous, the input data from TDO
        /// will not be available until some time after this builder's data has been
        /// applied.  This method assumes that you will eventually call JTAG.read(R)
        /// to collect the results, where @bitSizeOf(R) == @bitSizeOf(T).
        pub fn dr_out_in(self: *@This(), comptime T: type, value: T) !void {
            self.state(.dr_shift);
            self.shift(T, value, true);
        }

        pub fn linger(self: *@This(), clocks: u32) !void {
            const bit: Out_Bit = switch (self.current_state) {
                .reset => .{ .tms = 1 },
                .idle, .dr_pause, .ir_pause => .{ .tms = 0 },
                else => return error.InvalidState,
            };
            for (0..clocks) |_| {
                self.append(bit);
            }
        }

        pub fn idle(self: *@This(), clocks: u32) !void {
            try self.state(.idle);
            try self.linger(clocks);
        }

        fn append(self: *@This(), bit: Out_Bit) !void {
            const limit = switch (self.wip_push_isr) {
                false => 31,
                true => 63,
            };
            if (self.wip_count >= limit) {
                try self.flush();
            }
            const wip_count = self.wip_count;
            const byte = self.wip_count / 4;
            var bits = self.wip_bits[byte];
            switch (wip_count % 4) {
                0 => bits.b0 = bit,
                1 => bits.b1 = bit,
                2 => bits.b2 = bit,
                3 => bits.b3 = bit,
                else => unreachable,
            }
            self.wip_bits[byte] = bits;
            self.wip_count = wip_count + 1;
        }

        pub fn flush(self: *@This()) !void {
            if (self.wip_delay == 0 and self.wip_count == 0) return;
            try self.append(.{ .tms = @intFromBool(self.wip_push_isr and (self.wip_count % 32) != 0) });
            try self.push(@bitCast(Command {
                .delay = self.wip_delay,
                .bits = self.wip_count,
                .b0 = self.wip_bits[0],
                .b4 = self.wip_bits[1],
            }));
            if (self.wip_count > 8) {
                var remaining: []const Out_Bits_4 = self.wip_bits[2..];
                var remaining_bits: u32 = self.wip_count - 8;
                while (remaining_bits >= 16) {
                    try self.push(@bitCast(Out_Bits_16 {
                        .b0 = remaining[0],
                        .b4 = remaining[1],
                        .b8 = remaining[2],
                        .b12 = remaining[3],
                    }));
                    remaining = remaining[4..];
                    remaining_bits -= 16;
                }

                if (remaining_bits > 0) {
                    var final: Out_Bits_16 = .zeroes;
                    final.b0 = remaining[0];
                    if (remaining_bits > 4) final.b1 = remaining[1];
                    if (remaining_bits > 8) final.b2 = remaining[2];
                    if (remaining_bits > 12) final.b3 = remaining[3];
                    try self.push(@bitCast(final));
                }
            }

            self.wip_delay = 0;
            self.wip_count = 0;
        }

        fn push(self: *@This(), data: u32) !void {
            if (self.len >= buffer_len) return error.OutOfMemory;
            self.buffer[self.len] = data;
            self.len += 1;
        }
    };
}

const Out_Bits_16 = packed struct (u32) {
    b0: Out_Bits_4,
    b4: Out_Bits_4,
    b8: Out_Bits_4,
    b12: Out_Bits_4,

    pub const zeroes: Out_Bits_16 = .{
        .b0 = .zeroes,
        .b4 = .zeroes,
        .b8 = .zeroes,
        .b12 = .zeroes,
    };
};

const Out_Bits_4 = packed struct (u8) {
    b0: Out_Bit,
    b1: Out_Bit,
    b2: Out_Bit,
    b3: Out_Bit,

    pub const zeroes: Out_Bits_4 = .{
        .b0 = .zeroes,
        .b1 = .zeroes,
        .b2 = .zeroes,
        .b3 = .zeroes,
    };
};

const Out_Bit = packed struct (u2) {
    tms: u1,
    tdi: u1 = 0,

    pub const zeroes: Out_Bit = .{
        .tms = 0,
        .tdi = 0,
    };
};

const Command = packed struct (u32) {
    delay: u10,
    bits: u6,
    b0: Out_Bits_4,
    b4: Out_Bits_4,
};

pub const Config = struct {
    out_len: comptime_int,
    in_len: comptime_int,
};

pub fn JTAG(comptime config: Config) type {
    return struct {
        out: FIFO(u32, config.out_len),
        in: FIFO(u32, config.in_len),
        state: State,

        pub const empty: @This() = .{
            .out = .empty,
            .in = .empty,
            .state = .unknown,
        };

        pub fn update(self: *@This()) void {
            while (rx_fifo_not_empty() and self.in.available() > 0) {
                self.in.push(read_rx_fifo()) catch unreachable;
            }
            while (tx_fifo_not_full() and self.out.len > 0) {
                write_tx_fifo(self.out.pop() catch unreachable);
            }
        }

        pub fn read(self: *@This(), comptime T: type) !T {
            const expected_words = (@bitSizeOf(T) + 31) / 32;
            std.debug.assert(expected_words <= config.in_len);
            if (self.in.len < expected_words) return error.NotReady;
            var result: T = undefined;
            var result_bytes = std.mem.asBytes(&result);
            var bits_remaining: u32 = @bitSizeOf(T);
            while (bits_remaining >= 32) {
                const word = self.in.pop() catch unreachable;
                @memcpy(result_bytes.ptr, std.mem.asBytes(&word));
                result_bytes = result_bytes[4..];
                bits_remaining -= 32;
            }
            if (bits_remaining > 0) {
                std.debug.assert(result_bytes.len <= 4);
                const raw = self.in.pop() catch unreachable;
                const shifted = raw >> @intCast(32 - bits_remaining);
                @memcpy(result_bytes, std.mem.asBytes(&shifted).ptr);
            }
            return result;
        }

        pub fn builder(self: *const @This()) Builder {
            return .init(self.state);
        }

        fn rx_fifo_not_empty() bool {
            return true; // TODO
        }

        fn read_rx_fifo() u32 {
            return 0; // TODO
        }

        fn tx_fifo_not_full() bool {
            return true; // TODO
        }

        fn write_tx_fifo(val: u32) void {
            _ = val;
        }

    };
}

pub fn FIFO(comptime T: type, comptime len: comptime_int) type {
    return struct {
        data: [len]T,
        head: u16,
        len: u16,

        pub const empty: @This() = .{
            .data = undefined,
            .head = 0,
            .len = 0,
        };

        pub fn available(self: *const @This()) u16 {
            return len - self.len;
        }

        pub fn push(self: *@This(), val: T) void {
            if (self.len >= len) return error.Overflow;
            var tail: u32 = self.head;
            tail += self.len;
            if (tail > len) {
                tail -= len;
            }
            self.data[tail] = val;
            self.len += 1;
        }

        pub fn peek(self: *const @This()) ?T {
            return if (self.len == 0) null else self.data[self.head];
        }

        pub fn consume(self: *@This()) !void {
            if (self.len == 0) return error.Underflow;
            var new_head = self.head + 1;
            if (new_head >= len) {
                new_head -= len;
            }
            self.head = new_head;
            self.len -= 1;
        }

        pub fn pop(self: *@This()) !T {
            const val = self.peek() orelse return error.Underflow;
            self.consume() catch unreachable;
            return val;
        }
    };
}

const util = struct {
    pub inline fn to_int(comptime T: type, value: anytype) T {
        return switch (@typeInfo(@TypeOf(value))) {
            .@"enum" => @intFromEnum(value),
            .pointer => @intFromPtr(value),
            else => @bitCast(value),
        };
    }
};

const std = @import("std");
