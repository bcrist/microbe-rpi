const std = @import("std");
const Build = std.Build;

const Boot2ChecksumStep = @This();

step: Build.Step,
source: Build.LazyPath,
output_file: Build.GeneratedFile,

pub fn create(owner: *Build, bin_source: Build.LazyPath) *Boot2ChecksumStep {
    var self = owner.allocator.create(Boot2ChecksumStep) catch @panic("OOM");
    self.* = .{
        .step = Build.Step.init(.{
            .id = .custom,
            .name = owner.fmt("boot2_checksum {s}", .{ bin_source.getDisplayName() }),
            .owner = owner,
            .makeFn = make,
        }),
        .source = bin_source,
        .output_file = .{
            .step = &self.step,
        },
        .include_data = false,
    };
    bin_source.addStepDependencies(&self.step);
    return self;
}

/// deprecated: use getOutput
pub const getOutputSource = getOutput;

pub fn getOutput(self: *const Boot2ChecksumStep) Build.LazyPath {
    return .{ .generated = &self.output_file };
}

fn make(step: *Build.Step, progress: *std.Progress.Node) !void {
    _ = progress;

    const b = step.owner;
    const self = @fieldParentPtr(Boot2ChecksumStep, "step", step);

    var man = b.cache.obtain();
    defer man.deinit();

    // Random bytes to make hash unique. Refresh this with new random
    // bytes when hash implementation is modified incompatibly.
    man.hash.add(@as(u32, 0xacda_b87f));

    const full_src_path = self.source.getPath(b);
    _ = try man.addFile(full_src_path, null);

    if (try step.cacheHit(&man)) {
        // Cache hit, skip subprocess execution.
        const digest = man.final();
        self.output_file.path = try b.cache_root.join(b.allocator, &.{
            "microbe",
            &digest,
            self.source.getDisplayName(),
        });
        return;
    }

    const digest = man.final();
    const cache_dir = "microbe" ++ std.fs.path.sep_str ++ digest;
    const full_dest_path = try b.cache_root.join(b.allocator, &.{ cache_dir, self.source.getDisplayName() });
    b.cache_root.handle.makePath(cache_dir) catch |err| {
        return step.fail("unable to make path {s}: {s}", .{ cache_dir, @errorName(err) });
    };

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const raw = b.build_root.handle.readFileAlloc(arena.allocator(), full_src_path, 1_000_000_000) catch |err| {
        return step.fail("unable to open '{s}': {s}", .{ full_src_path, @errorName(err) });
    };

    if (raw.len < 252) {
        return step.fail("input binary too small; expected >= 252 bytes in {s}", .{ full_src_path });
    }

    const raw_boot2 = raw[0..252];
    var crc = std.hash.crc.Crc32Mpeg2.hash(raw_boot2);
    var crc_stream = std.io.fixedBufferStream(raw[252..256]);

    const previous_crc = try crc_stream.reader().readIntLittle(u32);
    if (previous_crc != crc) {
        std.log.info("Replacing boot2 checksum: {X} -> {X}", .{ previous_crc, crc });
    }

    crc_stream.reset();
    try crc_stream.writer().writeIntLittle(u32, crc);

    b.build_root.handle.writeFile(full_dest_path, raw) catch |err| {
        return step.fail("unable to write '{s}': {s}", .{ full_dest_path, @errorName(err) });
    };

    self.output_file.path = full_dest_path;
    try man.writeManifest();
}
