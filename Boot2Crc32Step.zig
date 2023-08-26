const std = @import("std");
const Build = std.Build;

const Boot2Crc32Step = @This();

step: Build.Step,
source: Build.LazyPath,
output_file: Build.GeneratedFile,

pub fn create(owner: *Build, source: Build.LazyPath) *Boot2Crc32Step {
    var self = owner.allocator.create(Boot2Crc32Step) catch @panic("OOM");
    self.* = .{
        .step = Build.Step.init(.{
            .id = .custom,
            .name = "boot2_crc32",
            .owner = owner,
            .makeFn = make,
        }),
        .source = source,
        .output_file = .{
            .step = &self.step,
        },
    };
    source.addStepDependencies(&self.step);
    return self;
}

pub fn getOutputSource(self: *const Boot2Crc32Step) Build.LazyPath {
    return .{ .generated = &self.output_file };
}

fn make(step: *Build.Step, progress: *std.Progress.Node) !void {
    _ = progress;

    const b = step.owner;
    const self = @fieldParentPtr(Boot2Crc32Step, "step", step);

    var man = b.cache.obtain();
    defer man.deinit();

    // Random bytes to make ObjCopy unique. Refresh this with new random
    // bytes when ObjCopy implementation is modified incompatibly.
    man.hash.add(@as(u32, 0xe18b7baf));

    const full_src_path = self.source.getPath(b);
    _ = try man.addFile(full_src_path, null);

    const digest = man.final();
    self.output_file.path = try b.cache_root.join(b.allocator, &.{
        "microbe",
        &digest,
        "boot2.zig",
    });

    if (try step.cacheHit(&man)) {
        // Cache hit, skip subprocess execution.
        return;
    }

    var buf: [4001]u8 = undefined;
    const raw_boot2 = try b.build_root.handle.readFile(full_src_path, &buf);

    if (raw_boot2.len == 0) {
        std.log.err("boot2 section is empty; did you forget to export a boot2 function?", .{});
        return error.InvalidBoot2Section;
    } else if (raw_boot2.len > 252) {
        if (raw_boot2.len > 4000) {
            std.log.err("Expected boot2 section to be <= 252 bytes; found > 4000", .{});
        } else {
            std.log.err("Expected boot2 section to be <= 252 bytes; found {}", .{ raw_boot2.len });
        }
        return error.InvalidBoot2Section;
    }

    var crc = std.hash.crc.Crc32Mpeg2.hash(raw_boot2);
    var crc_stream = std.io.fixedBufferStream(buf[252..256]);
    try crc_stream.writer().writeIntLittle(u32, crc);

    var file = try b.cache_root.handle.createFile(self.output_file.getPath(), .{});
    defer file.close();

    const writer = file.writer();

    try writer.writeAll(
        \\// This file was auto-generated by microbe\n");
        \\export const _boot2: [252]u8 linksection(".boot2") = .{
        \\
    );

    for (0..31) |line| {
        const bytes = buf[line * 8 ..][0..8];
        try writer.print("    0x{X:0>2}, 0x{X:0>2}, 0x{X:0>2}, 0x{X:0>2}, 0x{X:0>2}, 0x{X:0>2}, 0x{X:0>2}, 0x{X:0>2},\n", .{
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
        });
    }

    try writer.print(
        \\    0x{X:0>2}, 0x{X:0>2}, 0x{X:0>2}, 0x{X:0>2},
        \\}};
        \\
        \\export const _boot2_checksum: u32 linksection(".boot2_checksum") = 0x{X};
        \\
        \\
        , .{ buf[248], buf[249], buf[250], buf[251], crc });

    try man.writeManifest();
}
