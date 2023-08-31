const std = @import("std");
const Build = std.Build;

const Boot2Crc32Step = @This();

step: Build.Step,
sources: []const Build.LazyPath,
output_file: Build.GeneratedFile,
include_data: bool,

pub fn create(owner: *Build, sources: []const Build.LazyPath) *Boot2Crc32Step {
    var self = owner.allocator.create(Boot2Crc32Step) catch @panic("OOM");
    self.* = .{
        .step = Build.Step.init(.{
            .id = .custom,
            .name = "boot2_crc32",
            .owner = owner,
            .makeFn = make,
        }),
        .sources = owner.allocator.dupe(Build.LazyPath, sources) catch @panic("OOM"),
        .output_file = .{
            .step = &self.step,
        },
        .include_data = false,
    };
    for (sources) |src| {
        src.addStepDependencies(&self.step);
    }
    return self;
}

/// deprecated: use getOutput
pub const getOutputSource = getOutput;

pub fn getOutput(self: *const Boot2Crc32Step) Build.LazyPath {
    return .{ .generated = &self.output_file };
}

fn make(step: *Build.Step, progress: *std.Progress.Node) !void {
    _ = progress;

    const b = step.owner;
    const self = @fieldParentPtr(Boot2Crc32Step, "step", step);

    var man = b.cache.obtain();
    defer man.deinit();

    // Random bytes to make hash unique. Refresh this with new random
    // bytes when hash implementation is modified incompatibly.
    man.hash.add(@as(u32, 0xacda_b87f));

    for (self.sources) |src| {
        _ = try man.addFile(src.getPath(b), null);
    }

    if (try step.cacheHit(&man)) {
        // Cache hit, skip subprocess execution.
        const digest = man.final();
        self.output_file.path = try b.cache_root.join(b.allocator, &.{
            "microbe",
            &digest,
            "boot2.zig",
        });
        return;
    }

    const digest = man.final();
    self.output_file.path = try b.cache_root.join(b.allocator, &.{
        "microbe",
        &digest,
        "boot2.zig",
    });
    const cache_dir = "microbe" ++ std.fs.path.sep_str ++ digest;
    b.cache_root.handle.makePath(cache_dir) catch |err| {
        return step.fail("unable to make path {s}: {s}", .{ cache_dir, @errorName(err) });
    };

    var buf: [4001]u8 = undefined;
    @memset(&buf, 0);

    var remaining: []u8 = &buf;

    for (self.sources) |src| {
        const data = try b.build_root.handle.readFile(src.getPath(b), remaining);
        remaining = remaining[data.len..];
    }

    const actual_length = buf.len - remaining.len;

    if (actual_length == 0) {
        std.log.err("boot2 section is empty; did you forget to export a boot2 function?", .{});
        return error.InvalidBoot2Section;
    } else if (actual_length > 252) {
        if (actual_length > 4000) {
            std.log.err("Expected boot2 section to be <= 252 bytes; found > 4000", .{});
        } else {
            std.log.err("Expected boot2 section to be <= 252 bytes; found {}", .{ actual_length });
        }
        return error.InvalidBoot2Section;
    }

    const raw_boot2 = buf[0..252];
    var crc = std.hash.crc.Crc32Mpeg2.hash(raw_boot2);
    var crc_stream = std.io.fixedBufferStream(buf[252..256]);
    try crc_stream.writer().writeIntLittle(u32, crc);

    var file = try b.cache_root.handle.createFile(self.output_file.getPath(), .{});
    defer file.close();

    const writer = file.writer();

    try writer.writeAll(
        \\// This file was auto-generated by microbe
        \\
    );

    if (self.include_data) {
        try writer.writeAll(
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
            , .{ buf[248], buf[249], buf[250], buf[251] }
        );
    }

    try writer.print(
        \\
        \\export const _boot2_checksum: u32 linksection(".boot2_checksum") = 0x{X};
        \\
        \\
        , .{ crc }
    );

    try man.writeManifest();
}
