pub const Exception = chip.reg_types.Exception;
pub const Interrupt = chip.reg_types.Interrupt;

pub const Handler = extern union {
    C: *const fn () callconv(.C) void,
    Naked: *const fn () callconv(.Naked) void,

    pub fn wrap(comptime function: anytype) Handler {
        const cc = @typeInfo(@TypeOf(function)).Fn.calling_convention;
        return switch (cc) {
            .C => .{ .C = function },
            .Naked => .{ .Naked = function },
            .Unspecified => .{
                .C = struct {
                    fn wrapper() callconv(.C) void {
                        @call(.always_inline, function, .{});
                    }
                }.wrapper,
            },
            else => @compileError("unsupported calling convention for exception handler: " ++ @tagName(cc)),
        };
    }

    pub fn address(self: Handler) usize {
        return switch (self) {
            .C => |ptr| @intFromEnum(ptr),
            .Naked => |ptr| @intFromEnum(ptr),
        };
    }
};

pub fn unhandled(comptime e: Exception) Handler {
    const H = struct {
        pub fn unhandled() callconv(.C) noreturn {
            @panic("unhandled " ++ @tagName(e));
        }
    };
    return .{ .C = H.unhandled };
}

pub fn is_enabled(comptime irq: Interrupt) bool {
    return @field(peripherals.NVIC.interrupt_set_enable.read(), @tagName(irq));
}

pub fn set_enabled(comptime irq: Interrupt, comptime enabled: bool) void {
    if (enabled) {
        const T = peripherals.NVIC.interrupt_set_enable.Raw_Type;
        const val = T{};
        @field(val, @tagName(irq)) = true;
        peripherals.NVIC.interrupt_set_enable.write(val);
    } else {
        const T = peripherals.NVIC.interrupt_clear_enable.Raw_Type;
        const val = T{};
        @field(val, @tagName(irq)) = true;
        peripherals.NVIC.interrupt_clear_enable.write(val);
    }
}

pub const configure_enables = util.configure_interrupt_enables;

pub fn get_priority(comptime e: Exception) u8 {
    if (e.to_interrupt()) |irq| {
        const reg_name = std.fmt.comptimePrint("interrupt_priority_{}", .{ @intFromEnum(irq) / 4 });
        const val = @field(peripherals.NVIC, reg_name).read();
        return @field(val, @tagName(irq));
    } else return switch (e) {
        .SVCall => peripherals.SCB.exception_priority_2.read().SVCall,
        .PendSV => peripherals.SCB.exception_priority_3.read().PendSV,
        .SysTick => peripherals.SCB.exception_priority_3.read().SysTick,
        else => @compileError("Exception priority is fixed!"),
    };
}

pub fn set_priority(comptime e: Exception, priority: u8) void {
    if (e.to_interrupt()) |irq| {
        const reg_name = std.fmt.comptimePrint("interrupt_priority_{}", .{ @intFromEnum(irq) / 4 });
        const val = @field(peripherals.NVIC, reg_name).read();
        @field(val, @tagName(irq)) = priority;
        @field(peripherals.NVIC, reg_name).write(val);
    } else switch (e) {
        .SVCall => peripherals.SCB.exception_priority_2.modify(.{ .SVCall = priority }),
        .PendSV => peripherals.SCB.exception_priority_3.modify(.{ .PendSV = priority }),
        .SysTick => peripherals.SCB.exception_priority_3.modify(.{ .SysTick = priority }),
        else => @compileError("Exception priority is fixed!"),
    }
}

pub const configure_priorities = util.configure_interrupt_priorities;

pub fn is_pending(comptime e: Exception) bool {
    if (e.to_interrupt()) |irq| {
        return @field(peripherals.NVIC.interrupt_set_pending.read(), @tagName(irq));
    } else return switch (e) {
        .NMI => peripherals.SCB.interrupt_control_state.read().set_pending_NMI,
        .PendSV => peripherals.SCB.interrupt_control_state.read().set_pending_PendSV,
        .SysTick => peripherals.SCB.interrupt_control_state.read().set_pending_SysTick,
        else => @compileError("Unsupported exception type!"),
    };
}

pub fn set_pending(comptime e: Exception, comptime pending: bool) void {
    if (e.to_interrupt()) |irq| {
        if (pending) {
            const T = peripherals.NVIC.interrupt_set_pending.Raw_Type;
            const val = T{};
            @field(val, @tagName(irq)) = 1;
            peripherals.NVIC.interrupt_set_pending.write(val);
        } else {
            const T = peripherals.NVIC.interrupt_clear_pending.Raw_Type;
            const val = T{};
            @field(val, @tagName(irq)) = 1;
            peripherals.NVIC.interrupt_clear_pending.write(val);
        }
    } else switch (e) {
        .NMI => {
            if (!pending) {
                @compileError("NMI can't be unpended!");
            }
            peripherals.SCB.interrupt_control_state.write(.{ .set_pending_NMI = true });
        },
        .PendSV => {
            if (pending) {
                peripherals.SCB.interrupt_control_state.write(.{ .set_pending_PendSV = true });
            } else {
                peripherals.SCB.interrupt_control_state.write(.{ .clear_pending_PendSV = true });
            }
        },
        .SysTick => {
            if (pending) {
                peripherals.SCB.interrupt_control_state.write(.{ .set_pending_SysTick = true });
            } else {
                peripherals.SCB.interrupt_control_state.write(.{ .clear_pending_SysTick = true });
            }
        },
        else => @compileError("Unsupported exception type!"),
    }
}

pub inline fn are_globally_enabled() bool {
    return !asm volatile ("mrs r0, primask"
        : [ret] "={r0}" (-> bool),
        :
        : "r0"
    );
}

pub inline fn set_globally_enabled(comptime enabled: bool) void {
    if (enabled) {
        asm volatile ("cpsie i");
    } else {
        asm volatile ("cpsid i");
    }
}

pub inline fn current_exception() Exception {
    return peripherals.SCB.interrupt_control_state.read().active_exception_number;

    // TODO this should be faster, but causes a compiler crash in zig 0.12.0-dev.2341+92211135f:
    // return asm volatile ("mrs r0, ipsr"
    //     : [ret] "={r0}" (-> Exception),
    //     :
    //     : "r0"
    // );
}

pub inline fn is_in_handler() bool {
    return current_exception() != .none;
}

pub inline fn wait_for_interrupt() void {
    asm volatile ("wfi" ::: "memory");
}

pub inline fn wait_for_event() void {
    asm volatile ("wfe" ::: "memory");
}

pub inline fn send_event() void {
    asm volatile ("sev");
}

const peripherals = chip.peripherals;
const chip = @import("chip");
const util = @import("microbe").util;
const std = @import("std");
