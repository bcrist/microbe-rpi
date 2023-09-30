const microbe = @import("microbe");
const chip = @import("chip");

pub const pads = microbe.ComptimeResourceValidator(chip.PadID, "pad");
pub const dma = microbe.ComptimeResourceValidator(chip.dma.Channel, "DMA channel");
