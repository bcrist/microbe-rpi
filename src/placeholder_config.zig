const std = @import("std");

pub const chip_name = "Placeholder";
pub const core_name = "Placeholder";

pub const target = "Placeholder";

pub const runtime_resource_validation = true;
    
pub const regions = struct {
    pub const flash = mem_slice(0x0, 0x100);
    pub const ram = mem_slice(0x100, 0x200);
};

pub fn init_ram() callconv(.C) void {
    @setCold(true);
}

fn mem_slice(comptime begin: u32, comptime len: u32) []u8 {
    var slice: []u8 = undefined;
    slice.ptr = @ptrFromInt(begin);
    slice.len = len;
    return slice;
}
