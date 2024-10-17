// These come from the linker and indicates where the stack segments end, which
// is where the initial stack pointer should be.  It's not a function, but by
// pretending that it is, zig realizes that its address is constant, which doesn't
// happen with declaring it as extern const anyopaque and then taking its address.
// We need it to be comptime constant so that we can put it in the comptime
// constant VectorTable.
extern var _core0_stack_end: anyopaque;
extern var _core1_stack_end: anyopaque;

/// This is the entry point after XIP has been enabled by boot2.
/// All it does is initialize core 0's SP and then call _start()
pub fn boot3() linksection(".boot3_entry") callconv(.C) noreturn {
    asm volatile (
        \\ mov sp, %[stack]
        :
        : [stack] "r" (&_core0_stack_end)
        : "memory"
    );
    _start();
    unreachable;
}

/// This is the logical entry point for microbe.
/// It will invoke the main function from the root source file and provide error return handling
export fn _start() linksection(".boot3") callconv(.C) noreturn {
    peripherals.SCB.vector_table.write(&core0_vt);

    // We don't do this in boot2 in order to conserve space, and it's not
    // needed there because the clock isn't initialized to full speed yet.
    peripherals.PADS_QSPI.sclk.write(.{
        .speed = .fast,
        .strength = .@"8mA",
        .input_enabled = false,
    });
    peripherals.PADS_QSPI.sd[0].write(.{
        .speed = .fast,
        .hysteresis = false,
    });
    peripherals.PADS_QSPI.sd[1].write(.{
        .speed = .fast,
        .hysteresis = false,
    });
    peripherals.PADS_QSPI.sd[2].write(.{
        .speed = .fast,
        .hysteresis = false,
    });
    peripherals.PADS_QSPI.sd[3].write(.{
        .speed = .fast,
        .hysteresis = false,
    });

    if (@hasDecl(root, "earlyInit")) {
        root.earlyInit();
    }

    resets.reset(.{
        .pads_bank0 = true,
        .io_bank0 = true,
    });

    peripherals.WATCHDOG.control.modify(.{
        .enable_countdown = false,
    });

    clocks.init();

    config.init_ram();

    if (@hasDecl(root, "init")) {
        root.init();
    }

    // if (@hasDecl(root, "core1_main")) {
    //     // TODO start core1
    // }

    const main_fn = if (@hasDecl(root, "core0_main")) root.core0_main
        else if (@hasDecl(root, "main")) root.main
        else @compileError("The root source file must provide a public function main!");

    const info: std.builtin.Type = @typeInfo(@TypeOf(main_fn));

    if (info != .@"fn" or info.@"fn".params.len > 0) {
        @compileError("main must be either 'pub fn main() void' or 'pub fn main() !void'.");
    }

    if (info.@"fn".calling_convention == .Async) {
        @compileError("TODO: Event loop not supported.");
    }

    if (@typeInfo(info.@"fn".return_type.?) == .error_union) {
        main_fn() catch |err| @panic(@errorName(err));
    } else {
        main_fn();
    }

    @panic("main() returned!");
}

pub const core0_vt: Vector_Table align(0x100) linksection(".core0_vt") = init_vector_table("core0");
pub const core1_vt: Vector_Table align(0x100) linksection(".core1_vt") = init_vector_table("core1");

fn init_vector_table(comptime core_id: []const u8) Vector_Table {
    var vt: Vector_Table = .{
        .initial_stack_pointer = &@field(@This(), "_" ++ core_id ++ "_stack_end"),
        .Reset = Exception_Handler.wrap(microbe.hang),
    };
    if (@hasDecl(root, "handlers")) {
        if (@typeInfo(root.handlers) != .@"struct") {
            @compileLog("root.handlers must be a struct");
        }

        inline for (@typeInfo(root.handlers).@"struct".decls) |decl| {
            const field = @field(root.handlers, decl.name);
            switch (@typeInfo(@TypeOf(field))) {
                .@"struct" => |struct_info| if (std.mem.eql(u8, decl.name, core_id)) {
                    inline for (struct_info.decls) |core_decl| {
                        const core_field = @field(field, core_decl.name);
                        if (@hasField(Exception, core_decl.name)) {
                            @field(vt, core_decl.name) = Exception_Handler.wrap(core_field);
                        } else {
                            @compileError(core_decl.name ++ " is not a valid exception handler name!");
                        }
                    }
                },
                .@"fn" => if (@hasField(Exception, decl.name)) {
                    @field(vt, decl.name) = Exception_Handler.wrap(field);
                } else {
                    @compileError(decl.name ++ " is not a valid exception handler name!");
                },
                else => {},
            }
        }
    }
    return vt;
}

pub fn reset_current_core() noreturn {
    peripherals.SCB.reset_control.write(.{ .request_core_reset = true });
    unreachable;
}

pub const Reset_Source = enum {
    unknown,
    watchdog_forced,
    watchdog_timeout,
    power_on_or_brown_out,
    external_run_pin,
    debug_port,
};
/// Note this doesn't track individual core resets (i.e. reset_current_core())
pub fn get_last_reset_source() Reset_Source {
    switch (peripherals.WATCHDOG.last_reset_reason.read().reason) {
        .watchdog_timeout => return .watchdog_timeout,
        .watchdog_forced => return .watchdog_forced,
        .chip_reset => {},
    }
    const data = peripherals.VREG_AND_CHIP_RESET.CHIP_RESET.read();
    if (data.HAD_POR) return .power_on_or_brown_out;
    if (data.HAD_RUN) return .external_run_pin;
    if (data.HAD_PSM_RESTART) return .debug_port;
    return .unknown;
}

pub const Core_ID = enum(u8) {
    core0 = 0,
    core1 = 1,
};
pub fn get_current_core_id() Core_ID {
    return @enumFromInt(peripherals.SIO.core_id.read());
}

pub fn get_initial_stack_pointer() *anyopaque {
    return switch (get_current_core_id()) {
        .core0 => &_core0_stack_end,
        .core1 => &_core1_stack_end,
    };
}

const clocks = @import("clocks.zig");
const resets = @import("resets.zig");
const peripherals = @import("peripherals.zig");
const reg_types = chip.reg_types;
const Vector_Table = reg_types.Vector_Table;
const Exception = chip.interrupts.Exception;
const Exception_Handler = chip.interrupts.Handler;
const chip = @import("../rp2040.zig");
const config = @import("config");
const microbe = @import("microbe");
const root = @import("root");
const std = @import("std");
