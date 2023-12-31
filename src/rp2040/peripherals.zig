// Generated by https://github.com/bcrist/microbe-regz
const types = @import("reg_types.zig");

pub const ADC: *volatile types.adc.ADC = @ptrFromInt(0x4004C000);
pub const CLOCKS: *volatile types.clk.CLOCKS = @ptrFromInt(0x40008000);
pub const FREQ_COUNTER: *volatile types.clk.FREQ_COUNTER = @ptrFromInt(0x40008080);
pub const PLL_SYS: *volatile types.clk.PLL = @ptrFromInt(0x40028000);
pub const PLL_USB: *volatile types.clk.PLL = @ptrFromInt(0x4002C000);
pub const ROSC: *volatile types.clk.ROSC = @ptrFromInt(0x40060000);
pub const XOSC: *volatile types.clk.XOSC = @ptrFromInt(0x40024000);
pub const MPU: *volatile types.cortex.MPU = @ptrFromInt(0xE000ED90);
pub const NVIC: *volatile types.cortex.NVIC = @ptrFromInt(0xE000E100);
pub const SCB: *volatile types.cortex.SCB = @ptrFromInt(0xE000ED00);
pub const SYSTICK: *volatile types.cortex.SYSTICK = @ptrFromInt(0xE000E010);
pub const DMA: *volatile types.dma.DMA = @ptrFromInt(0x50000400);
pub const DMA_CH: *volatile types.dma.DMA_CH = @ptrFromInt(0x50000000);
pub const DMA_DEBUG: *volatile types.dma.DMA_DEBUG = @ptrFromInt(0x50000800);
pub const I2C0: *volatile types.i2c.I2C = @ptrFromInt(0x40044000);
pub const I2C1: *volatile types.i2c.I2C = @ptrFromInt(0x40048000);
pub const IO: *volatile types.io.IO = @ptrFromInt(0x40014000);
pub const IO_INT: *volatile types.io.IO_INT = @ptrFromInt(0x400140F0);
pub const IO_QSPI: *volatile types.io.IO_QSPI = @ptrFromInt(0x40018000);
pub const IO_QSPI_INT: *volatile types.io.IO_QSPI_INT = @ptrFromInt(0x40018030);
pub const PADS: *volatile types.io.PADS = @ptrFromInt(0x4001C000);
pub const PADS_QSPI: *volatile types.io.PADS_QSPI = @ptrFromInt(0x40020000);
pub const PIO0: *volatile types.pio.PIO = @ptrFromInt(0x50200000);
pub const PIO1: *volatile types.pio.PIO = @ptrFromInt(0x50300000);
pub const PWM: *volatile types.pwm.PWM = @ptrFromInt(0x40050000);
pub const RTC: *volatile types.rtc.RTC = @ptrFromInt(0x4005C000);
pub const SPI0: *volatile types.spi.SPI = @ptrFromInt(0x4003C000);
pub const SPI1: *volatile types.spi.SPI = @ptrFromInt(0x40040000);
pub const BUSCTRL: *volatile types.sys.BUSCTRL = @ptrFromInt(0x40030000);
pub const PSM: *volatile types.sys.PSM = @ptrFromInt(0x40010000);
pub const RESETS: *volatile types.sys.RESETS = @ptrFromInt(0x4000C000);
pub const SIO: *volatile types.sys.SIO = @ptrFromInt(0xD0000000);
pub const SSI: *volatile types.sys.SSI = @ptrFromInt(0x18000000);
pub const SYSCFG: *volatile types.sys.SYSCFG = @ptrFromInt(0x40004000);
pub const SYSINFO: *volatile types.sys.SYSINFO = @ptrFromInt(0x40000000);
pub const VREG_AND_CHIP_RESET: *volatile types.sys.VREG_AND_CHIP_RESET = @ptrFromInt(0x40064000);
pub const WATCHDOG: *volatile types.sys.WATCHDOG = @ptrFromInt(0x40058000);
pub const XIP_CTRL: *volatile types.sys.XIP_CTRL = @ptrFromInt(0x14000000);
pub const TIMER: *volatile types.timer.TIMER = @ptrFromInt(0x40054000);
pub const UART0: *volatile types.uart.UART = @ptrFromInt(0x40034000);
pub const UART1: *volatile types.uart.UART = @ptrFromInt(0x40038000);
pub const USB_BUF: *volatile types.usb.USB_BUF = @ptrFromInt(0x50100000);
pub const USB_DEV: *volatile types.usb.USB_DEV = @ptrFromInt(0x50110000);
pub const USB_HOST: *volatile types.usb.USB_HOST = @ptrFromInt(0x50110000);
