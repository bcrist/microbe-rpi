const std = @import("std");
const microbe = @import("microbe");
const rpi = @import("microbe-rpi");

pub fn build(b: *std.Build) void {
    var rpi_dep = b.dependency("microbe-rpi", .{});

    const chip = rpi.rp2040(1024, 2, 50_000_000); // clk_sys is limited to 100MHz

    const boot2_module = rpi.addBoot2(b, .{
        .name = "boot2-zd25q80c-div2",
        .root_source_file = rpi_dep.module("boot2-zd25q").source_file,
        .chip = chip,
    });

    var exe = microbe.addExecutable(b, .{
        .name = "example.elf",
        .root_source_file = .{ .path = "main.zig" },
        .chip = chip,
        .sections = rpi.defaultSections(),
        .optimize = b.standardOptimizeOption(.{}),
    });
    exe.addModule("boot2", boot2_module);
    b.installArtifact(exe);

    // var objcopy_step = example.addObjCopy(.{ .format = .bin });
    // const install_bin_step = b.addInstallBinFile(objcopy_step.getOutputSource(), "example.bin");
    // install_bin_step.step.dependOn(&objcopy_step.step);
    // b.default_step.dependOn(&install_bin_step.step);

    // var flash = b.addSystemCommand(&.{
    //     "C:\\Program Files (x86)\\STMicroelectronics\\STM32 ST-LINK Utility\\ST-LINK Utility\\ST-LINK_CLI.exe",
    //     "-c", "SWD", "UR", "LPM",
    //     "-P", b.getInstallPath(.bin, "example.bin"), "0x08000000",
    //     "-V", "after_programming",
    //     "-HardRst", "PULSE=100",
    // });
    // flash.step.dependOn(&install_bin_step.step);
    // const flash_step = b.step("flash", "Flash firmware with ST-LINK");
    // flash_step.dependOn(&flash.step);
}
