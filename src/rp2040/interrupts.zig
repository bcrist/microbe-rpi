const std = @import("std");
const chip = @import("chip");
const util = @import("chip_util");

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

pub const unhandled = Handler { .C = _unhandled };
fn _unhandled() callconv(.C) noreturn {
    @panic("unhandled");
}

pub fn isEnabled(comptime irq: Interrupt) bool {
    return @field(chip.NVIC.interrupt_set_enable.read(), @tagName(irq));
}

pub fn setEnabled(comptime irq: Interrupt, comptime enabled: bool) void {
    if (enabled) {
        const T = chip.NVIC.interrupt_set_enable.RawType;
        const val = T{};
        @field(val, @tagName(irq)) = true;
        chip.NVIC.interrupt_set_enable.write(val);
    } else {
        const T = chip.NVIC.interrupt_clear_enable.RawType;
        const val = T{};
        @field(val, @tagName(irq)) = true;
        chip.NVIC.interrupt_clear_enable.write(val);
    }
}

pub const configureEnables = util.configureInterruptEnables;

pub fn getPriority(comptime e: Exception) u8 {
    if (e.toInterrupt()) |irq| {
        const reg_name = std.fmt.comptimePrint("interrupt_priority_{}", .{ @intFromEnum(irq) / 4 });
        const val = @field(chip.NVIC, reg_name).read();
        return @field(val, @tagName(irq));
    } else return switch (e) {
        .SVCall => chip.SCB.exception_priority_2.read().SVCall,
        .PendSV => chip.SCB.exception_priority_3.read().PendSV,
        .SysTick => chip.SCB.exception_priority_3.read().SysTick,
        else => @compileError("Exception priority is fixed!"),
    };
}

pub fn setPriority(comptime e: Exception, priority: u8) void {
    if (e.toInterrupt()) |irq| {
        const reg_name = std.fmt.comptimePrint("interrupt_priority_{}", .{ @intFromEnum(irq) / 4 });
        const val = @field(chip.NVIC, reg_name).read();
        @field(val, @tagName(irq)) = priority;
        @field(chip.NVIC, reg_name).write(val);
    } else switch (e) {
        .SVCall => chip.SCB.exception_priority_2.modify(.{ .SVCall = priority }),
        .PendSV => chip.SCB.exception_priority_3.modify(.{ .PendSV = priority }),
        .SysTick => chip.SCB.exception_priority_3.modify(.{ .SysTick = priority }),
        else => @compileError("Exception priority is fixed!"),
    }
}

pub const configurePriorities = util.configureInterruptPriorities;

pub fn isPending(comptime e: Exception) bool {
    if (e.toInterrupt()) |irq| {
        return @field(chip.NVIC.interrupt_set_pending.read(), @tagName(irq));
    } else return switch (e) {
        .NMI => chip.SCB.interrupt_control_state.read().set_pending_NMI,
        .PendSV => chip.SCB.interrupt_control_state.read().set_pending_PendSV,
        .SysTick => chip.SCB.interrupt_control_state.read().set_pending_SysTick,
        else => @compileError("Unsupported exception type!"),
    };
}

pub fn setPending(comptime e: Exception, comptime pending: bool) void {
    if (e.toInterrupt()) |irq| {
        if (pending) {
            const T = chip.NVIC.interrupt_set_pending.RawType;
            const val = T{};
            @field(val, @tagName(irq)) = 1;
            chip.NVIC.interrupt_set_pending.write(val);
        } else {
            const T = chip.NVIC.interrupt_clear_pending.RawType;
            const val = T{};
            @field(val, @tagName(irq)) = 1;
            chip.NVIC.interrupt_clear_pending.write(val);
        }
    } else switch (e) {
        .NMI => {
            if (!pending) {
                @compileError("NMI can't be unpended!");
            }
            chip.SCB.interrupt_control_state.write(.{ .set_pending_NMI = true });
        },
        .PendSV => {
            if (pending) {
                chip.SCB.interrupt_control_state.write(.{ .set_pending_PendSV = true });
            } else {
                chip.SCB.interrupt_control_state.write(.{ .clear_pending_PendSV = true });
            }
        },
        .SysTick => {
            if (pending) {
                chip.SCB.interrupt_control_state.write(.{ .set_pending_SysTick = true });
            } else {
                chip.SCB.interrupt_control_state.write(.{ .clear_pending_SysTick = true });
            }
        },
        else => @compileError("Unsupported exception type!"),
    }
}

pub inline fn areGloballyEnabled() bool {
    return !asm volatile ("mrs r0, primask"
        : [ret] "={r0}" (-> bool),
        :
        : "r0"
    );
}

pub inline fn setGloballyEnabled(comptime enabled: bool) void {
    if (enabled) {
        asm volatile ("cpsie i");
    } else {
        asm volatile ("cpsid i");
    }
}

pub inline fn currentException() Exception {
    // Another way to implement this would be:
    // chip.SCB.interrupt_control_state.read().active_exception_number
    // but this is faster:
    return !asm volatile ("mrs r0, ipsr"
        : [ret] "={r0}" (-> Exception),
        :
        : "r0"
    );
}

pub inline fn isInHandler() bool {
    return currentException() != .none;
}

pub inline fn waitForInterrupt() void {
    asm volatile ("wfi");
}

pub inline fn waitForEvent() void {
    asm volatile ("wfe");
}

pub inline fn sendEvent() void {
    asm volatile ("sev");
}
