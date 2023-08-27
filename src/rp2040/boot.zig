const std = @import("std");
const root = @import("root");
const chip = @import("chip");
const microbe = @import("microbe");
// const clocks = @import("clocks.zig");
const reg_types = chip.reg_types;
const VectorTable = reg_types.VectorTable;
const Exception = chip.interrupts.Exception;
const ExceptionHandler = chip.interrupts.Handler;

// These come from the linker and indicates where the stack segments end, which
// is where the initial stack pointer should be.  It's not a function, but by
// pretending that it is, zig realizes that its address is constant, which doesn't
// happen with declaring it as extern const anyopaque and then taking its address.
// We need it to be comptime constant so that we can put it in the comptime
// constant VectorTable.
extern fn _core0_stack_end() void;
extern fn _core1_stack_end() void;

// Defined in the config module
extern fn _init_ram() void;

/// This is the entry point after XIP has been enabled by boot2.
/// All it does is initialize core 0's SP and then call _start()
export fn _boot3() linksection(".boot3_entry") callconv(.Naked) noreturn {
    asm volatile (
        \\ mov sp, %[stack]
        \\ bx %[start]
        :
        : [start] "r" (&_start),
          [stack] "r" (&_core0_stack_end)
        : "memory"
    );
}

/// This is the logical entry point for microbe.
/// It will invoke the main function from the root source file and provide error return handling
export fn _start() linksection(".boot3") callconv(.C) noreturn {
    _init_ram();

    chip.SCB.vector_table.write(&_core0_vt);

    // clocks.init(root.clocks);

    if (@hasDecl(root, "init")) {
        root.init();
    }

    // if (@hasDecl(root, "core1_main")) {
    //     // TODO start core1
    // }

    const main_fn = if (@hasDecl(root, "core0_main")) @field(root, "core0_main")
        else if (@hasDecl(root, "main")) @field(root, "main")
        else @compileError("The root source file must provide a public function main!");

    const info: std.builtin.Type = @typeInfo(@TypeOf(main_fn));

    if (info != .Fn or info.Fn.params.len > 0) {
        @compileError("main must be either 'pub fn main() void' or 'pub fn main() !void'.");
    }

    if (info.Fn.calling_convention == .Async) {
        @compileError("TODO: Event loop not supported.");
    }

    if (@typeInfo(info.Fn.return_type.?) == .ErrorUnion) {
        main_fn() catch |err| @panic(@errorName(err));
    } else {
        main_fn();
    }

    resetCurrentCore();
}

export const _core0_vt: VectorTable linksection(".core0_vt") = initVectorTable("core0");
export const _core1_vt: VectorTable linksection(".core1_vt") = initVectorTable("core1");

fn initVectorTable(comptime core_id: []const u8) VectorTable {
    var vt: VectorTable = .{
        .initial_stack_pointer = &@field(@This(), "_" ++ core_id ++ "_stack_end"),
        .Reset = ExceptionHandler.wrap(microbe.hang),
    };
    if (@hasDecl(root, "handlers")) {
        if (@typeInfo(root.handlers) != .Struct) {
            @compileLog("root.handlers must be a struct");
        }

        inline for (@typeInfo(root.handlers).Struct.decls) |decl| {
            const field = @field(root.handlers, decl.name);
            switch (@typeInfo(field)) {
                .Struct => |struct_info| if (std.mem.eql(u8, decl.name, core_id)) {
                    inline for (struct_info.decls) |core_decl| {
                        const core_field = @field(field, core_decl.name);
                        if (@hasField(Exception, core_decl.name)) {
                            @field(vt, core_decl.name) = ExceptionHandler.wrap(core_field);
                        } else {
                            @compileError(core_decl.name ++ " is not a valid exception handler name!");
                        }
                    }
                },
                .Fn => if (@hasField(Exception, decl.name)) {
                    @field(vt, decl.name) = ExceptionHandler.wrap(field);
                } else {
                    @compileError(decl.name ++ " is not a valid exception handler name!");
                },
                else => {},
            }
        }
    }
    return vt;
}

pub fn resetCurrentCore() noreturn {
    // TODO if core0, we should reset the whole chip.  Otherwise just reset core1
    chip.SCB.reset_control.write(.{ .request_core_reset = true });
    unreachable;
}

pub const ChipResetSource = enum {
    unknown,
    power_on_or_brown_out,
    external_run_pin,
    debug_port,
};
/// Note this doesn't track watchdog resets, core resets, etc.
pub fn getLastChipResetSource() ChipResetSource {
    const data = chip.VREG_AND_CHIP_RESET.CHIP_RESET.read();
    if (data.HAD_POR) return .power_on_or_brown_out;
    if (data.HAD_RUN) return .external_run_pin;
    if (data.HAD_PSM_RESTART) return .debug_port;
    return .unknown;
}

pub const CoreID = enum(u8) {
    core0 = 0,
    core1 = 1,
};
pub fn getCurrentCoreID() CoreID {
    return @enumFromInt(chip.SIO.CPUID.read());
}
