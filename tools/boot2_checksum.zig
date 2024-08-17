pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var arg_iter = try std.process.argsWithAllocator(arena.allocator());
    defer arg_iter.deinit();

    const input_path = arg_iter.next() orelse return error.ExpectedInputPath;
    const output_path = arg_iter.next() orelse return error.ExpectedOutputPath;

    const file_contents = try std.fs.cwd().readFileAlloc(arena.allocator(), input_path, 1_000_000_000);

    if (file_contents.len < 252) {
        std.io.getStdErr().writer().print("input binary too small; expected >= 252 bytes in {s}", .{ input_path });
        return error.InvalidBinary;
    }

    const raw_boot2 = file_contents[0..252];
    const crc = std.hash.crc.Crc32Mpeg2.hash(raw_boot2);
    var crc_stream = std.io.fixedBufferStream(file_contents[252..256]);

    const previous_crc = try crc_stream.reader().readInt(u32, .little);
    if (previous_crc != crc) {
        std.log.info("Replacing boot2 checksum: {X} -> {X}", .{ previous_crc, crc });
    }

    crc_stream.reset();
    try crc_stream.writer().writeInt(u32, crc, .little);

    try std.fs.cwd().writeFile(output_path, file_contents);
}

const std = @import("std");
