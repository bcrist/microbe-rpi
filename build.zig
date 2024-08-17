pub const Flash_Options = struct {
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

pub const zd25q80c = Flash_Options {
    .size_kibytes = 1024,
    .clock_div = 4,
    .max_frequency_hz = 50_000_000,
    .xip_mode_bits = 0xA0,
    .xip_wait_cycles = 4,
    .has_volatile_status_reg = true,
    .has_write_status_reg_1 = true,
    .quad_enable_bit = 9,
};

/// Max clk_sys of 100MHz, but lower latency for XIP loads than zd25q80c (clock_div == 4)
pub const zd25q80c_div2 = f: {
    var options = zd25q80c;
    options.clock_div = 2;
    break :f options;
};

pub const zd25q16c = f: {
    var options = zd25q80c;
    options.size_kibytes = 2048;
    options.clock_div = 2;
    options.max_flash_frequency_hz = 86_000_000;
    break :f options;
};

pub const zd25q32c = f: {
    var options = zd25q16c;
    options.size_kibytes = 4096;
    break :f options;
};

pub const zd25q64c = f: {
    var options = zd25q16c;
    options.size_kibytes = 8192;
    break :f options;
};

pub const rp2354_flash = Flash_Options {
    .size_kibytes = 2048,

    // TODO the rest of this is unknown, but RP2350 bootloader should set up the QSPI correctly for us
    .clock_div = 4,
    .max_frequency_hz = 100_000_000,
    .xip_mode_bits = 0xA0,
    .xip_wait_cycles = 4,
    .has_volatile_status_reg = true,
    .has_write_status_reg_1 = true,
    .quad_enable_bit = 9,
};

pub fn rp2040(comptime options: Flash_Options) Chip {
    return .{
        .name = "RP2040",
        .dependency_name = "microbe-rpi",
        .module_name = "rp2040",
        .core = Core.cortex_m0plus,
        .single_threaded = false,
        .memory_regions = comptime &.{
            Memory_Region.executable_rom("boot2_flash", 0x10000000, 0x100),
            Memory_Region.main_flash(0x10000100, options.size_kibytes * 1024 - 0x100),
            Memory_Region.main_ram(0x20000000, 256 * 1024),
            Memory_Region.executable_ram("xip_cache", 0x15000000, 16 * 1024),
            Memory_Region.executable_ram("sram4", 0x20040000, 4 * 1024),
            Memory_Region.executable_ram("sram5", 0x20041000, 4 * 1024),
            Memory_Region.executable_ram("boot2_sram5", 0x20041F00, 0x100),
            Memory_Region.executable_ram("usb_dpram", 0x50100000, 4 * 1024),
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

pub fn rp2350a(comptime options: Flash_Options) Chip {
    return rp2350("RP2350A", "rp2350a", options);
}

pub fn rp2350b(comptime options: Flash_Options) Chip {
    return rp2350("RP2350B", "rp2350b", options);
}

pub const rp2354a = rp2350a(rp2354_flash);
pub const rp2354b = rp2350b(rp2354_flash);

fn rp2350(comptime name: []const u8, comptime module_name: []const u8, comptime options: Flash_Options) Chip {
    return .{
        .name = name,
        .dependency_name = "microbe-rpi",
        .module_name = module_name,
        .core = Core.cortex_m33fpu,
        .single_threaded = false,
        .memory_regions = comptime &.{
            Memory_Region.main_flash(0x10000000, options.size_kibytes * 1024),
            Memory_Region.main_ram(0x20000000, 512 * 1024),
            Memory_Region.executable_ram("xip_cache", 0x10000000 + options.size_kibytes * 1024, 0x4000000 - options.size_kibytes * 1024),
            Memory_Region.executable_ram("sram8", 0x20080000, 4 * 1024),
            Memory_Region.executable_ram("sram9", 0x20081000, 4 * 1024),
            Memory_Region.ram("boot_ram", 0x400e0000, 1024),
            Memory_Region.ram("usb_dpram", 0x50100000, 4 * 1024),
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

pub fn default_rp2040_sections() []const Section {
    return comptime &.{
        // FLASH only:
        boot3_section(),
        Section.keep_rom_section("core0_vt", "flash"),
        Section.keep_rom_section("core1_vt", "flash"),
        Section.default_text_section(),
        Section.default_arm_extab_section(),
        Section.default_arm_exidx_section(),
        Section.default_rodata_section(),

        // RAM only:
        Section.stack_section("core0_stack", "sram4", 0),
        Section.stack_section("core1_stack", "sram5", 0), // Note the first 256 bytes of SRAM5 are also used for the stage2 bootloader

        // FLASH + RAM:
        Section.default_data_section(),

        // RAM only:
        Section.default_bss_section(),
        Section.default_udata_section(),
        Section.default_heap_section(),

        // FLASH only:
        Section.default_nvm_section(),

        // FLASH + RAM (copied to sram5 by boot1 ROM)
        boot2_section(),
    };
}

pub fn default_rp2350_sections() []const Section {
    return comptime &.{
        // FLASH only:
        Section.keep_rom_section("core0_vt", "flash"),
        Section.keep_rom_section("core1_vt", "flash"),
        boot3_section(),
        Section.default_text_section(),
        Section.default_arm_extab_section(),
        Section.default_arm_exidx_section(),
        Section.default_rodata_section(),

        // RAM only:
        Section.stack_section("core0_stack", "sram8", 0),
        Section.stack_section("core1_stack", "sram9", 0),

        // FLASH + RAM:
        Section.default_data_section(),

        // RAM only:
        Section.default_bss_section(),
        Section.default_udata_section(),
        Section.default_heap_section(),

        // FLASH only:
        Section.default_nvm_section(),
    };
}

pub fn boot2_section() Section {
    return .{
        .name = "boot2",
        .contents = &.{
            \\KEEP(*(.boot2_entry))
            \\    KEEP(*(.boot2))
            \\    FILL(0xFFFFFFFF);
            \\    . = _boot2_start + 0xFC;
            \\    KEEP(*(.boot2_checksum))
            \\    . = _boot2_start + 0x100;
        },
        .rom_region = "boot2_flash",
        .ram_region = "boot2_sram5",
        .skip_init = true,
    };
}

pub fn boot3_section() Section {
    return .{
        .name = "boot3",
        .contents = &.{
            \\PROVIDE(_boot3 = .);
            \\    KEEP(*(.boot3_entry))
            \\    KEEP(*(.boot3))
        },
        .rom_region = "flash",
    };
}

pub const Boot2_Options = struct {
    name: ?[]const u8 = null,
    source: union(enum) {
        module: *std.Build.Module,
        path: std.Build.LazyPath,
    },
    chip: microbe.Chip,
    optimize: std.builtin.Mode = .ReleaseSmall,
};

pub fn add_boot2_object(b: *std.Build, options: Boot2_Options) *std.Build.Step.Compile {
    const generate_config_exe = b.dependency("microbe", .{}).artifact("generate_config");
    const generate_config = b.addRunArtifact(generate_config_exe);
    generate_config.addArg("-o");
    const config_module_path = generate_config.addOutputFileArg("config.zig");
    microbe.add_chip_and_section_args(generate_config, .{
        .name = "",
        .chip = options.chip,
        .sections = default_rp2040_sections(),
    });
    const config_module = b.createModule(.{ .root_source_file = config_module_path });

    const chip_module = b.dependencyFromBuildZig(@This(), .{}).module(options.chip.module_name);
    const rt_module = chip_module.import_table.get("microbe").?;

    config_module.addImport("chip", chip_module);

    var object = b.addObject(.{
        .name = options.name orelse "boot2",
        .root_source_file = switch (options.source) {
            .module => |module| module.root_source_file.?,
            .path => |path| path,
        },
        .optimize = options.optimize,
        .target = b.resolveTargetQuery(options.chip.core.target),
        .single_threaded = options.chip.single_threaded,
    });

    switch (options.source) {
        .path => {},
        .module => |m| {
            m.root_source_file.?.addStepDependencies(&object.step);
            var iter = m.import_table.iterator();
            while (iter.next()) |entry| {
                object.root_module.addImport(entry.key_ptr.*, entry.value_ptr.*);
            }
        },
    }
    object.root_module.addImport("microbe", rt_module);
    object.root_module.addImport("config", config_module);
    object.root_module.addImport("chip", chip_module);

    return object;
}

pub fn boot2_checksum(b: *std.Build, bin: std.Build.LazyPath) std.Build.LazyPath {
    const exe = b.dependencyFromBuildZig(@This(), .{}).artifact("boot2_checksum");
    const run = b.addRunArtifact(exe);
    run.addFileArg(bin);
    return run.addOutputFileArg("boot2.bin");
}

pub fn build(b: *std.Build) void {
    const microbe_module = b.dependency("microbe", .{}).module("microbe");
    const placeholder_config_module = b.createModule(.{ .root_source_file = b.path("src/placeholder_config.zig") });
    
    inline for (&.{ "rp2040", "rp2350a", "rp2350b" }) |name| {
        const microbe_clone = microbe.clone_module(microbe_module);
        const chip_module = b.addModule(name, .{ .root_source_file = b.path("src/" ++ name ++ ".zig") });
        chip_module.addImport("microbe", microbe_clone);
        chip_module.addImport("config", placeholder_config_module);
        chip_module.addImport("chip", chip_module);
        
        var replacement_modules = std.StringHashMap(*std.Build.Module).init(b.allocator);
        replacement_modules.put("microbe", microbe_clone) catch unreachable;
        replacement_modules.put("config", placeholder_config_module) catch unreachable;
        replacement_modules.put("chip", chip_module) catch unreachable;
        microbe.replace_imports(microbe_clone, &replacement_modules);
    }

    _ = b.addModule("boot2-default", .{ .root_source_file = b.path("src/boot2/default.zig") });

    _ = b.addExecutable(.{
        .name = "boot2_checksum",
        .root_source_file = b.path("tools/boot2_checksum.zig"),
        .target = b.host,
        .optimize = .ReleaseSafe,
    });
}

const Chip = microbe.Chip;
const Core = microbe.Core;
const Section = microbe.Section;
const Memory_Region = microbe.Memory_Region;
const microbe = @import("microbe");
const std = @import("std");
