const std = @import("std");
const microbe = @import("microbe");
const Boot2Crc32Step = @import("Boot2Crc32Step.zig");
const Chip = microbe.Chip;
const Core = microbe.Core;
const Section = microbe.Section;
const MemoryRegion = microbe.MemoryRegion;

pub const FlashOptions = struct {
    size_kibytes: u32,

    /// clock_div must be even and >= 2.
    /// The max clk_sys will be clock_div * max_frequency_hz
    clock_div: u8,

    /// You may want to adjust this based on the speed noted in your QSPI memory's datasheet.
    /// Most 25Qxx style chips will support 50 MHz or more.
    max_frequency_hz: u32,

    // These are used by the default boot2 implementation to set up XIP mode:
    xip_mode_bits: u8,
    xip_wait_cycles: u8,
    has_volatile_status_reg: bool,
    has_write_status_reg_1: bool,
    quad_enable_bit: u8,
};

pub fn zd25q80c() FlashOptions {
    return .{
        .size_kibytes = 1024,
        .clock_div = 4,
        .max_frequency_hz = 50_000_000,
        .xip_mode_bits = 0xA0,
        .xip_wait_cycles = 4,
        .has_volatile_status_reg = true,
        .has_write_status_reg_1 = true,
        .quad_enable_bit = 9,
    };
}

/// Max clk_sys of 100MHz, but lower latency for XIP loads than zd25q80c (clock_div == 4)
pub fn zd25q80c_div2() FlashOptions {
    var options = zd25q80c();
    options.clock_div = 2;
    return options;
}

pub fn zd25q16c() FlashOptions {
    var options = zd25q80c();
    options.size_kibytes = 2048;
    options.clock_div = 2;
    options.max_flash_frequency_hz = 86_000_000;
    return options;
}

pub fn zd25q32c() FlashOptions {
    var options = zd25q16c();
    options.size_kibytes = 4096;
    return options;
}

pub fn zd25q64c() FlashOptions {
    var options = zd25q16c();
    options.size_kibytes = 8192;
    return options;
}

pub fn rp2040(comptime options: FlashOptions) Chip {
    return .{
        .name = "RP2040",
        .dependency_name = "microbe-rpi",
        .module_name = "rp2040",
        .core = Core.cortex_m0plus,
        .single_threaded = false,
        .memory_regions = comptime &.{
            MemoryRegion.mainFlash(0x10000000, options.size_kibytes * 1024),
            MemoryRegion.mainRam(0x20000000, 256 * 1024),
            MemoryRegion.executableRam("xip_cache", 0x15000000, 16 * 1024),
            MemoryRegion.executableRam("sram4", 0x20040000, 4 * 1024),
            MemoryRegion.executableRam("sram5", 0x20041000, 4 * 1024),
            MemoryRegion.executableRam("usb_dpram", 0x50100000, 4 * 1024),
        },
        .extra_config = comptime &.{
            .{ .name = "flash_clock_div",               .value = std.fmt.comptimePrint("{}", .{ options.clock_div }) },
            .{ .name = "max_flash_frequency_hz",        .value = std.fmt.comptimePrint("{}", .{ options.max_frequency_hz }) },
            .{ .name = "xip_mode_bits",                 .value = std.fmt.comptimePrint("0x{X}", .{ options.xip_mode_bits }) },
            .{ .name = "xip_wait_cycles",               .value = std.fmt.comptimePrint("{}", .{ options.xip_wait_cycles }) },
            .{ .name = "flash_has_volatile_status_reg", .value = std.fmt.comptimePrint("{}", .{ options.has_volatile_status_reg }) },
            .{ .name = "flash_has_write_status_reg_1",  .value = std.fmt.comptimePrint("{}", .{ options.has_write_status_reg_1 }) },
            .{ .name = "flash_quad_enable_bit",         .value = std.fmt.comptimePrint("{}", .{ options.quad_enable_bit }) },
        },
    };
}

pub fn defaultSections() []const Section {
    return comptime &.{
        // FLASH + RAM (copied to sram5 by boot1 ROM)
        boot2Section(),

        // FLASH only:
        boot3Section(),
        Section.keepRomSection("core0_vt", "flash"),
        Section.keepRomSection("core1_vt", "flash"),
        Section.defaultTextSection(),
        Section.defaultArmExtabSection(),
        Section.defaultArmExidxSection(),
        Section.defaultRoDataSection(),

        // RAM only:
        Section.stackSection("core0_stack", "sram4", 0),
        Section.stackSection("core1_stack", "sram5", 0), // Note the first 256 bytes of SRAM5 are also used for the stage2 bootloader

        // FLASH + RAM:
        Section.defaultDataSection(),

        // RAM only:
        Section.defaultBssSection(),
        Section.defaultUDataSection(),
        Section.defaultHeapSection(),

        // FLASH only:
        Section.defaultNvmSection(),
    };
}

pub fn boot2Section() Section {
    return .{
        .name = "boot2",
        .contents = &.{
            \\KEEP(*(.boot2_entry))
            \\KEEP(*(.boot2))
            \\FILL(0x00);
            \\. = _boot2_start + 0xFC;
            \\KEEP(*(.boot2_checksum))
            \\. = _boot2_start + 0x100;
        },
        .rom_region = "flash",
        .ram_region = "sram5",
        .skip_init = true,
    };
}

pub fn boot3Section() Section {
    return .{
        .name = "boot3",
        .contents = &.{
            \\PROVIDE(_boot3 = .);
            \\KEEP(*(.boot3_entry))
            \\KEEP(*(.boot3))
        },
        .rom_region = "flash",
    };
}

pub const Boot2Options = struct {
    name: ?[]const u8 = null,
    source: union(enum) {
        module: *std.Build.Module,
        path: std.Build.LazyPath,
    },
    chip: microbe.Chip,
    optimize: std.builtin.Mode = .ReleaseSmall,
};

pub fn addChecksummedBoot2(b: *std.Build, options: Boot2Options) *std.Build.Step.Compile {
    // TODO consider using custom chip/sections so that the compiler can't accidentally place functions outside the 256-byte boot2 range?

    const microbe_dep = b.dependency("microbe", .{});
    const empty_module = microbe_dep.module("empty");

    const config_step = microbe.ConfigStep.create(b, options.chip, defaultSections());

    const chip_dep = b.dependency(options.chip.dependency_name, .{});
    const chip_module = chip_dep.module(options.chip.module_name);
    const rt_module = chip_module.dependencies.get("microbe").?;

    const config_module = b.createModule(.{
        .source_file = config_step.getOutput(),
        .dependencies = &.{
            .{ .name = "chip", .module = chip_module },
        },
    });

    // Initially, build without the .boot2_checksum symbol:
    var object = b.addObject(.{
        .name = options.name orelse "boot2",
        .root_source_file = switch (options.source) {
            .module => |module| .{ .path = module.source_file.getPath(module.builder) },
            .path => |path| path,
        },
        .optimize = options.optimize,
        .target = options.chip.core.target,
        .single_threaded = options.chip.single_threaded,
    });
    switch (options.source) {
        .path => {},
        .module => |m| {
            m.source_file.addStepDependencies(&object.step);
            var iter = m.dependencies.iterator();
            while (iter.next()) |entry| {
                object.addModule(entry.key_ptr.*, entry.value_ptr.*);
            }
        },
    }
    object.addModule("microbe", rt_module);
    object.addModule("config", config_module);
    object.addModule("chip", chip_module);
    object.addModule("checksum", empty_module);

    // Compute the new checksum:
    var extract_boot2_entry = object.addObjCopy(.{
        .format = .bin,
        .only_section = ".boot2_entry",
    });
    var extract_boot2 = object.addObjCopy(.{
        .format = .bin,
        .only_section = ".boot2",
    });
    var checksum = Boot2Crc32Step.create(b, &.{ extract_boot2_entry.getOutput(), extract_boot2.getOutput() });
    var checksum_module = b.createModule(.{ .source_file = checksum.getOutput() });

    // Recompile with the .boot2_checksum symbol:
    const final_object_name = if (options.name) |name| std.fmt.allocPrint(b.allocator, "{s}_checksummed", .{ name }) catch @panic("OOM") else "boot2_checksummed";
    var final_object = b.addObject(.{
        .name = final_object_name,
        .root_source_file = switch (options.source) {
            .module => |module| .{ .path = module.source_file.getPath(module.builder) },
            .path => |path| path,
        },
        .optimize = options.optimize,
        .target = options.chip.core.target,
        .single_threaded = options.chip.single_threaded,
    });
    switch (options.source) {
        .path => {},
        .module => |m| {
            m.source_file.addStepDependencies(&final_object.step);
            var iter = m.dependencies.iterator();
            while (iter.next()) |entry| {
                final_object.addModule(entry.key_ptr.*, entry.value_ptr.*);
            }
        },
    }
    final_object.addModule("microbe", rt_module);
    final_object.addModule("config", config_module);
    final_object.addModule("chip", chip_module);
    final_object.addModule("checksum", checksum_module);

    return final_object;
}

pub fn addBinToUf2(b: *std.Build, input_file: std.Build.LazyPath) *microbe.BinToUf2Step {
    return microbe.addBinToUf2(b, input_file, .{
        .base_address = 0x1000_0000,
        .block_size = 256,
        .family_id = 0xE48BFF56,
    });
}

pub fn build(b: *std.Build) void {
    const chips: []const []const u8 = &.{
        "rp2040",
    };

    const microbe_dep = b.dependency("microbe", .{});
    const microbe_module = microbe_dep.module("microbe");
    const chip_util_module = microbe_dep.module("chip_util");

    for (chips) |name| {
        const module = b.addModule(name, .{
            .source_file = .{
                .path = std.fmt.allocPrint(b.allocator, "src/{s}.zig", .{ name }) catch @panic("OOM"),
            },
            .dependencies = &.{
                .{ .name = "microbe", .module = microbe_module },
                .{ .name = "chip_util", .module = chip_util_module },
            },
        });
        module.dependencies.put("chip", module) catch @panic("OOM");
    }

    _ = b.addModule("boot2-default", .{ .source_file = .{ .path = "src/boot2/default.zig" }});
}
