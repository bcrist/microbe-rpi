pub const pads = microbe.Comptime_Resource_Validator(chip.Pad_ID, "pad");
pub const dma = microbe.Comptime_Resource_Validator(chip.dma.Channel, "DMA channel");

const chip = @import("chip");
const microbe = @import("microbe");
