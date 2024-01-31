pub const Channel = enum(u4) {
    channel0 = 0,
    channel1 = 1,
    channel2 = 2,
    channel3 = 3,
    channel4 = 4,
    channel5 = 5,
    channel6 = 6,
    channel7 = 7,
    channel8 = 8,
    channel9 = 9,
    channel10 = 10,
    channel11 = 11,
};


pub fn abort_channel(comptime channel: Channel) void {
    const ch = @intFromEnum(channel);
    const mask = @as(u32, 1) << ch;
    const bitmap: chip.reg_types.dma.Channel_Bitmap = @bitCast(mask);

    const irq0_enables: u32 = @bitCast(peripherals.DMA.irq0.enable.read());
    peripherals.DMA.irq0.enable.write(@bitCast(irq0_enables & ~mask));

    const irq1_enables: u32 = @bitCast(peripherals.DMA.irq1.enable.read());
    peripherals.DMA.irq1.enable.write(@bitCast(irq1_enables & ~mask));

    peripherals.DMA.abort.write(bitmap);

    while (peripherals.DMA_CH[ch].config.control.read().busy) {}

    peripherals.DMA.interrupt_status.write(bitmap);
}

const peripherals = @import("peripherals.zig");
const chip = @import("../rp2040.zig");
