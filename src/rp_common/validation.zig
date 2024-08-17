pub const pads = microbe.Bitset_Resource_Validator(chip.Pad_ID, "pad");
pub const dma = microbe.Bitset_Resource_Validator(chip.dma.Channel, "DMA channel");

const chip = @import("chip");
const microbe = @import("microbe");
