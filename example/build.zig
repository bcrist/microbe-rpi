const std = @import("std");
const microbe = @import("microbe");
const rpi = @import("microbe-rpi");

pub fn build(b: *std.Build) void {
    var rpi_dep = b.dependency("microbe-rpi", .{});

    const chip = rpi.rp2040(rpi.zd25q80c_div2);

    const boot2_object = rpi.add_boot2_object(b, .{
        .source = .{ .module = rpi_dep.module("boot2-default") },
        .chip = chip,
    });

    var exe = microbe.add_executable(b, .{
        .name = "example.elf",
        .root_source_file = .{ .path = "main.zig" },
        .chip = chip,
        .sections = rpi.default_sections(),
        .optimize = b.standardOptimizeOption(.{}),
    });
    exe.addObject(boot2_object);

    const bin = exe.addObjCopy(.{ .format = .bin });
    const checksummed_bin = rpi.Boot2_Checksum_Step.create(b, bin.getOutput());
    const install_bin = b.addInstallBinFile(checksummed_bin.get_output(), "example.bin");

    const uf2 = rpi.add_bin_to_uf2(b, checksummed_bin.get_output());
    const install_uf2 = b.addInstallBinFile(uf2.get_output(), "example.uf2");

    b.installArtifact(exe);
    b.getInstallStep().dependOn(&install_bin.step);
    b.getInstallStep().dependOn(&install_uf2.step);
}
