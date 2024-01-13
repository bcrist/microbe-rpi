const std = @import("std");
const usb = @import("microbe").usb;
const descriptor = usb.descriptor;
const endpoint = usb.endpoint;
const classes = usb.classes;
const Setup_Packet = usb.Setup_Packet;

pub fn get_device_descriptor() descriptor.Device {
    return .{
        .usb_version = .usb_2_0,
        .class = usb.hid.class.default,
        .vendor_id = 0x0000,
        .product_id = 0x0000,
        .version = .{
            .major = 1,
            .minor = 0,
        },
        .configuration_count = @intCast(configurations.len),
    };
}

const languages: descriptor.Supported_Languages(&.{
    .english_us,
}) = .{};
const strings = struct {
    const mfr_name: descriptor.String("Macrofluff") = .{};
    const product_name: descriptor.String("Wonderstuff") = .{};
    const serial_number: descriptor.String("12345") = .{};
};

pub fn get_string_descriptor(id: descriptor.String_ID, language: descriptor.Language) ?[]const u8 {
    if (id == .languages) return languages.as_bytes();
    return switch (language) {
        .english_us => switch (id) {
            .manufacturer_name => strings.mfr_name.as_bytes(),
            .product_name => strings.product_name.as_bytes(),
            .serial_number => strings.serial_number.as_bytes(),
            else => null,
        },
        else => null,
    };
}

const default_configuration = struct {
    pub const hid_interface = struct {
        pub const index = 0;
        pub const class = usb.hid.class.boot_keyboard;

        pub const in_endpoint = struct {
            pub const address: endpoint.Address = .{ .ep = 1, .dir = .in };
            pub const kind: endpoint.Transfer_Kind = .interrupt;
            pub const poll_interval_ms: u8 = 16;
        };

        pub const endpoints = .{ in_endpoint };

        pub const hid_descriptor: usb.hid.Descriptor(.us, .{ report_descriptor }) = .{};
        pub const report_descriptor: usb.hid.boot_keyboard.ReportDescriptor = .{};

        pub const Report = usb.hid.boot_keyboard.InputReport;
        pub const Status = usb.hid.boot_keyboard.OutputReport;
    };

    pub const interfaces = .{ hid_interface };

    pub const descriptors: DescriptorSet = .{};
    pub const DescriptorSet = packed struct {
        config: descriptor.Configuration = .{
            .number = 1,
            .name = @enumFromInt(0),
            .self_powered = false,
            .remote_wakeup = false,
            .max_current_ma_div2 = 50,
            .length_bytes = @bitSizeOf(DescriptorSet) / 8,
            .interface_count = @intCast(interfaces.len),
        },
        interface: descriptor.Interface = descriptor.Interface.parse(hid_interface),
        hid: usb.hid.Descriptor(.us, .{ hid_interface.report_descriptor }) = hid_interface.hid_descriptor,
        in_ep: descriptor.Endpoint = descriptor.Endpoint.parse(hid_interface.in_endpoint),
    };
};

const configurations = .{ default_configuration };

pub fn get_configuration_descriptor_set(configuration_index: u8) ?[]const u8 {
    inline for (0.., configurations) |i, configuration| {
        if (i == configuration_index) {
            return descriptor.as_bytes(&configuration.descriptors);
        }
    }
    return null;
}

pub fn get_interface_count(configuration: u8) u8 {
    inline for (configurations) |cfg| {
        if (cfg.descriptors.config.number == configuration) {
            return @intCast(cfg.interfaces.len);
        }
    }
    return 0;
}

pub fn get_endpoint_count(configuration: u8, interface_index: u8) u8 {
    inline for (configurations) |cfg| {
        if (cfg.descriptors.config.number == configuration) {
            inline for (0.., cfg.interfaces) |j, interface| {
                if (j == interface_index) {
                    return @intCast(interface.endpoints.len);
                }
            }
        }
    }
    return 0;
}

// Endpoint descriptors are not queried directly by hosts, but these are used to set up
// the hardware configuration for each endpoint.
pub fn get_endpoint_descriptor(configuration: u8, interface_index: u8, endpoint_index: u8) descriptor.Endpoint {
    inline for (configurations) |cfg| {
        if (cfg.descriptors.config.number == configuration) {
            inline for (0.., cfg.interfaces) |j, iface| {
                if (j == interface_index) {
                    inline for (0.., iface.endpoints) |k, ep| {
                        if (k == endpoint_index) {
                            return descriptor.Endpoint.parse(ep);
                        }
                    }
                }
            }
        }
    }
    unreachable;
}

/// This function can be used to provide class-specific descriptors associated with the device
pub fn get_descriptor(kind: descriptor.Kind, descriptor_index: u8) ?[]const u8 {
    _ = descriptor_index;
    _ = kind;
    return null;
}

/// This function can be used to provide class-specific descriptors associated with a particular interface, e.g. HID report descriptors
pub fn get_interface_specific_descriptor(interface: u8, kind: descriptor.Kind, descriptor_index: u8) ?[]const u8 {
    _ = descriptor_index;
    const hi = default_configuration.hid_interface;
    if (interface == hi.index) {
        switch (kind) {
            usb.hid.hid_descriptor => {
                return hi.hid_descriptor.as_bytes();
            },
            usb.hid.report_descriptor => {
                return hi.report_descriptor.as_bytes();
            },
            else => {},
        }
    }
    return null;
}

/// This function can be used to provide class-specific descriptors associated with a particular endpoint
pub fn get_endpoint_specific_descriptor(ep: endpoint.Index, kind: descriptor.Kind, descriptor_index: u8) ?[]const u8 {
    _ = descriptor_index;
    _ = kind;
    _ = ep;
    return null;
}

/// This function determines whether the USB engine should reply to non-control transactions with ACK or NAK
/// For .in endpoints, this should return true when we have some data to send.
/// For .out endpoints, this should return true when we can handle at least the max packet size of data for this endpoint.
pub fn is_endpoint_ready(address: endpoint.Address) bool {
    switch (address.dir) {
        .in => switch (address.ep) {
            default_configuration.hid_interface.in_endpoint.address.ep => {
                return report.is_endpoint_ready();
            },
            else => {},
        },
        else => {},
    }
    return false;
}

/// The buffer returned from this function only needs to remain valid briefly; it will be copied to an internal buffer.
/// If you don't have a buffer available, you can instead define:
pub fn fill_in_buffer(ep: endpoint.Index, data: []u8) u16 {
    switch (ep) {
        default_configuration.hid_interface.in_endpoint.address.ep => {
            const b = report.getInBuffer();
            @memcpy(data.ptr, b);
            return @intCast(b.len);
        },
        else => {},
    }
    return 0;
}

pub fn handle_out_buffer(ep: endpoint.Index, data: []volatile const u8) void {
    _ = data;
    _ = ep;
}

/// Called when a SOF packet is received
pub fn handle_start_of_frame() void {
    report.handle_start_of_frame();
}

/// Called when the host resets the bus
pub fn handle_bus_reset() void {
    report.reset();
}

/// Called when a set_configuration setup request is processed
pub fn handle_configuration_changed(configuration: u8) void {
    _ = configuration;
}

/// Used to respond to the get_status setup request
pub fn is_device_self_powered() bool {
    return false;
}

/// Handle any class/device-specific setup requests here.
/// Return true if the setup request is recognized and handled.
///
/// Requests where setup.data_len == 0 should call `device.setup_status_in()`.
/// Note this is regardless of whether setup.direction is .in or .out.
///
/// .in requests with a non-zero length should make one or more calls to `device.fill_setup_in(offset, data)`,
/// followed by a call to `device.setup_transfer_in(total_length)`, or just a single
/// call to `device.setup_transfer_in_data(data)`.  The data may be larger than the maximum EP0 transfer size.
/// In that case the data will need to be provided again using the `fill_setup_in` function below.
///
/// .out requests with a non-zero length should call `device.setup_transfer_out(setup.data_len)`.
/// The data will then be provided later via `handle_setup_out_buffer`
///
/// Note that this gets called even for standard requests that are normally handled internally.
/// You _must_ check that the packet matches what you're looking for specifically.
pub fn handle_setup(setup: Setup_Packet) bool {
    if (report.handle_setup(setup)) return true;
    if (status.handle_setup(setup)) return true;
    if (setup.kind == .class and setup.target == .interface) switch (setup.request) {
        usb.hid.requests.set_protocol => if (setup.direction == .out) {
            const payload: usb.hid.requests.ProtocolPayload = @bitCast(setup.payload);
            if (payload.interface == default_configuration.hid_interface.index) {
                std.log.scoped(.usb).info("set protocol: {}", .{ payload.protocol });
                device.setup_status_in();
                return true;
            }
        },
        usb.hid.requests.get_protocol => if (setup.direction == .in) {
            const payload: usb.hid.requests.ProtocolPayload = @bitCast(setup.payload);
            if (payload.interface == default_configuration.hid_interface.index) {
                std.log.scoped(.usb).info("get protocol", .{});
                const protocol: u8 = 0;
                device.setup_transfer_in_data(std.mem.asBytes(&protocol));
                return true;
            }
        },
        else => {},
    };
    return false;
}

/// If an .in setup request's data is too large for a single data packet,
/// this will be called after each buffer is transferred to fill in the next buffer.
/// If it returns false, endpoint 0 will be stalled.
/// Otherwise, it is assumed that the entire remaining data, or the entire buffer (whichever is smaller)
/// will be filled with data to send.
/// 
/// Normally this function should make one or more calls to `device.fill_setup_in(offset, data)`,
/// corresponding to the entire data payload, including parts that have already been sent.  The
/// parts outside the current buffer will automatically be ignored.
pub fn fill_setup_in(setup: Setup_Packet) bool {
    _ = setup;
    return false;
}

/// Return true if the setup request is recognized and the data buffer was processed.
pub fn handle_setup_out_buffer(setup: Setup_Packet, offset: u16, data: []volatile const u8, last_buffer: bool) bool {
    _ = last_buffer;
    return status.handle_setup_out_buffer(setup, offset, data);
}

pub fn init() void {
    device.init();
    report = @TypeOf(report).init(&device);
    status = @TypeOf(status).init(&device);
}

pub fn update() void {
    device.update();
}

var device: usb.USB(@This()) = .{};
var report: usb.hid.Input_Reporter(@This(), default_configuration.hid_interface.Report, .{
    .max_buffer_size = 16,
    .interface_index = 0,
    .report_id = 0,
    .default_idle_interval = .@"500ms",
}) = undefined;
var status: usb.hid.Output_Reporter(@This(), default_configuration.hid_interface.Status, .{
    .interface_index = 0,
    .report_id = 0,
}) = undefined;
