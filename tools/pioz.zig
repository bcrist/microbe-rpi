//! Like the pioasm tool from the RP-pico C SDK, but for zig.
//! Implemented from scratch based on the RP2040/RP2350 datasheets.
//! Not based on https://github.com/raspberrypi/pico-sdk/tree/master/tools/pioasm
//! Not based on https://github.com/ZigEmbeddedGroup/microzig/blob/main/port/raspberrypi/rp2xxx/src/hal/pio/assembler.zig
//!
//! Language-specific features (e.g. `% c-sdk { ... }%`, `.lang_opt`) are ignored.

const Assemble_Results = struct {
    instructions: []const u16,
    global_constants: []const Constant,
    programs: []const Program,
    diagnostics: []const Diagnostic,
};

const Program = struct {
    pio_version: PIO_Version,
    name: []const u8,
    constants: []const Constant,
    origin: u5,
    len: u6,
    wrap_source: u5,
    wrap_target: u5,
    clock_div: Clock_Divisor,
    status_mode: Status_Mode,
    fifo_mode: FIFO_Mode,
    in: struct {
        bits: u6,
        dir: Shift_Direction,
        auto_push: ?u3,
    },
    out: struct {
        bits: u6,
        dir: Shift_Direction,
        auto_pull: ?u3,
    },
    set_bits: u6,
    side_set: struct {
        bits: u3,
        optional: bool,
        mode: enum {
            pins,
            pin_dirs,
        },
    },

    pub const defaults: Program = .{
        .pio_version = .v1,
        .name = "",
        .constants = &.{},
        .origin = 0,
        .len = 0,
        .wrap_source = 31,
        .wrap_target = 0,
        .clock_div = .{
            .int = 1,
            .frac = 0,
        },
        .status_mode = .{ .rxfifo_less_than = 4 },
        .fifo_mode = .tx4_rx4,
        .in = .{
            .bits = 32,
            .dir = .left,
            .auto_push = true,
        },
        .out = .{
            .bits = 32,
            .dir = .right,
            .auto_pull = true,
        },
        .set_bits = 0,
        .side_set = .{
            .bits = 0,
            .optional = false,
            .mode = .pins,
        },
    };
};

const Diagnostic = union(enum) {
};

const Constant = struct {
    name: []const u8,
    value: usize,
};

const PIO_Version = enum {
    v0, // RP2040
    v1, // RP2350
};

const Clock_Divisor = struct {
    int: u16,
    frac: u8,
};

const FIFO_Mode = enum {
    tx4_rx4,
    tx8,
    rx8,
    tx4_put4,
    tx4_get4,
    put4_get4,
};

const Shift_Direction = enum {
    left,   // IN instructions place bits in the LSBs of the ISR.  OUT instructions take bits from the MSBs of the OSR.
    right,  // IN instructions place bits in the MSBs of the ISR.  OUT instructions take bits from the LSBs of the OSR.
};

const Status_Mode = union (enum) {
    rxfifo_less_than: u3,
    txfifo_less_than: u3,
    irq_set: u3,
    irq_set_next_pio: u3,
    irq_set_prev_pio: u3,
};

const Assemble_Options = struct {
    defaults: Program = .defaults,
    allow_exec: bool = false,
};

pub fn assemble(arena: std.mem.Allocator, temp: std.mem.Allocator, source: [:0]const u8, options: Assemble_Options) Assemble_Results {
    _ = arena;
    _ = temp;
    _ = options;
    _ = source;

    return .{
        .instructions = &.{},
        .global_constants = &.{},
        .programs = &.{},
        .diagnostics = &.{},
    };
}

const std = @import("std");
