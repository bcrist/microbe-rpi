const std = @import("std");
const microbe = @import("microbe");
const Boot2Crc32Step = @import("Boot2Crc32Step.zig");
const Chip = microbe.Chip;
const Core = microbe.Core;
const Section = microbe.Section;
const MemoryRegion = microbe.MemoryRegion;

pub fn rp2040(comptime flash_size_kibytes: usize, comptime flash_clk_div: u8, comptime max_flash_frequency_hz: u32) Chip {
    return .{
        .name = std.fmt.comptimePrint("RP2040 ({} kiB flash)", .{ flash_size_kibytes }),
        .dependency_name = "microbe-rpi",
        .module_name = "rp2040",
        .core = Core.cortex_m0plus,
        .single_threaded = false,
        .memory_regions = comptime &.{
            MemoryRegion.mainFlash(0x10000000, flash_size_kibytes * 1024),
            MemoryRegion.mainRam(0x20000000, 256 * 1024),
            MemoryRegion.executableRam("xip_cache", 0x15000000, 16 * 1024),
            MemoryRegion.executableRam("sram4", 0x20040000, 4 * 1024),
            MemoryRegion.executableRam("sram5", 0x20041000, 4 * 1024),
            MemoryRegion.executableRam("usb_dpram", 0x50100000, 4 * 1024),
        },
        .extra_config = comptime &.{
            .{
                .name = "flash_clock_div",
                .value = std.fmt.comptimePrint("{}", .{ flash_clk_div })
            },
            .{
                .name = "max_flash_frequency_hz",
                .value = std.fmt.comptimePrint("{}", .{ max_flash_frequency_hz })
            },
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

pub fn addChecksummedBoot2Module(b: *std.Build, options: Boot2Options) *std.Build.Module {
    const microbe_dep = b.dependency("microbe", .{});
    const empty_module = microbe_dep.module("empty");

    var boot2exe = microbe.addExecutable(b, .{
        .name = options.name orelse "boot2",
        .root_source_file = switch (options.source) {
            .module => |module| .{ .path = module.source_file.getPath(module.builder) },
            .path => |path| path,
        },
        .chip = options.chip,
        .sections = defaultSections(),
        .optimize = options.optimize,
    });
    boot2exe.addModule("boot2", empty_module);

    switch (options.source) {
        .module => |module| module.source_file.addStepDependencies(&boot2exe.step),
        .path => {},
    }

    var boot2extract = b.addObjCopy(boot2exe.getOutputSource(), .{
        .format = .bin,
        .only_section = ".boot2",
        .pad_to = 252,
    });

    var boot2 = Boot2Crc32Step.create(b, boot2extract.getOutputSource());
    boot2.step.dependOn(&boot2extract.step);

    if (options.name) |name| {
        return b.addModule(name, .{ .source_file = boot2.getOutputSource() });
    } else {
        return b.createModule(.{ .source_file = boot2.getOutputSource() });
    }
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

    _ = b.addModule("boot2-zd25q", .{ .source_file = .{ .path = "src/boot2/zd25q.zig" }});
}
