const root_path = "pioz_comparison_tests/";

const c = @cImport({
    @cDefine("PICO_NO_HARDWARE", "1");
    @cInclude("stdint.h");
    @cInclude(root_path ++ "addition.pio.h");
    @cInclude(root_path ++ "apa102.pio.h");
    @cInclude(root_path ++ "blink.pio.h");
    @cInclude(root_path ++ "clocked_input.pio.h");
    @cInclude(root_path ++ "differential_manchester.pio.h");
    @cInclude(root_path ++ "hello.pio.h");
    @cInclude(root_path ++ "hub75.pio.h");
    @cInclude(root_path ++ "i2c.pio.h");
    @cInclude(root_path ++ "irq.pio.h");
    @cInclude(root_path ++ "manchester_encoding.pio.h");
    @cInclude(root_path ++ "movrx.pio.h");
    @cInclude(root_path ++ "nec_carrier_burst.pio.h");
    @cInclude(root_path ++ "nec_carrier_control.pio.h");
    @cInclude(root_path ++ "nec_receive.pio.h");
    @cInclude(root_path ++ "pio_serialiser.pio.h");
    @cInclude(root_path ++ "pwm.pio.h");
    @cInclude(root_path ++ "quadrature_encoder.pio.h");
    @cInclude(root_path ++ "resistor_dac.pio.h");
    @cInclude(root_path ++ "spi.pio.h");
    @cInclude(root_path ++ "squarewave.pio.h");
    @cInclude(root_path ++ "squarewave_fast.pio.h");
    @cInclude(root_path ++ "squarewave_wrap.pio.h");
    @cInclude(root_path ++ "st7789_lcd.pio.h");
    @cInclude(root_path ++ "uart_rx.pio.h");
    @cInclude(root_path ++ "uart_tx.pio.h");
    @cInclude(root_path ++ "ws2812.pio.h");
});

test "addition"                 { try pioz_comparison("addition.pio",                   &.{ "addition" }); }
test "apa102"                   { try pioz_comparison("apa102.pio",                     &.{ "apa102_mini", "apa102_rgb555" }); }
test "blink"                    { try pioz_comparison("blink.pio",                      &.{ "blink" }); }
test "clocked_input"            { try pioz_comparison("clocked_input.pio",              &.{ "clocked_input" }); }
test "differential_manchester"  { try pioz_comparison("differential_manchester.pio",    &.{ "differential_manchester_tx", "differential_manchester_rx" }); }
test "hello"                    { try pioz_comparison("hello.pio",                      &.{ "hello" }); }
test "hub75"                    { try pioz_comparison("hub75.pio",                      &.{ "hub75_row", "hub75_data_rgb888" }); }
test "i2c"                      { try pioz_comparison("i2c.pio",                        &.{ "i2c", "set_scl_sda" }); }
test "irq"                      { try pioz_comparison("irq.pio",                        &.{ "irq" }); }
test "manchester_encoding"      { try pioz_comparison("manchester_encoding.pio",        &.{ "manchester_tx", "manchester_rx" }); }
test "movrx"                    { try pioz_comparison("movrx.pio",                      &.{ "movrx" }); }
test "nec_carrier_burst"        { try pioz_comparison("nec_carrier_burst.pio",          &.{ "nec_carrier_burst" }); }
test "nec_carrier_control"      { try pioz_comparison("nec_carrier_control.pio",        &.{ "nec_carrier_control" }); }
test "nec_receive"              { try pioz_comparison("nec_receive.pio",                &.{ "nec_receive" }); }
test "pio_serialiser"           { try pioz_comparison("pio_serialiser.pio",             &.{ "pio_serialiser" }); }
test "pwm"                      { try pioz_comparison("pwm.pio",                        &.{ "pwm" }); }
test "quadrature_encoder"       { try pioz_comparison("quadrature_encoder.pio",         &.{ "quadrature_encoder" }); }
test "resistor_dac"             { try pioz_comparison("resistor_dac.pio",               &.{ "resistor_dac_5bit" }); }
test "spi"                      { try pioz_comparison("spi.pio",                        &.{ "spi_cpha0", "spi_cpha1", "spi_cpha0_cs", "spi_cpha1_cs" }); }
test "squarewave"               { try pioz_comparison("squarewave.pio",                 &.{ "squarewave" }); }
test "squarewave_fast"          { try pioz_comparison("squarewave_fast.pio",            &.{ "squarewave_fast" }); }
test "squarewave_wrap"          { try pioz_comparison("squarewave_wrap.pio",            &.{ "squarewave_wrap" }); }
test "st7789_lcd"               { try pioz_comparison("st7789_lcd.pio",                 &.{ "st7789_lcd" }); }
test "uart_rx"                  { try pioz_comparison("uart_rx.pio",                    &.{ "uart_rx_mini", "uart_rx" }); }
test "uart_tx"                  { try pioz_comparison("uart_tx.pio",                    &.{ "uart_tx" }); }
test "ws2812"                   { try pioz_comparison("ws2812.pio",                     &.{ "ws2812", "ws2812_parallel" }); }

fn pioz_comparison(comptime path: []const u8, comptime program_names: []const []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();

    const results = pioz.assemble(arena.allocator(), std.testing.allocator, @embedFile(root_path ++ path), .{});

    try std.testing.expect(results.programs.len == program_names.len);

    inline for (program_names) |program_name| {
        const expected_insns = @field(c, program_name ++ "_program_instructions");
        for (results.programs) |program| {
            if (std.mem.eql(u8, program.name, program_name)) {
                const program_insns = results.instructions[program.origin..][0..program.len];
                for (0.., program_insns, expected_insns) |addr, actual, expected| {
                    errdefer std.debug.print("at address {d}\n", .{ addr });
                    try std.testing.expectEqual(expected, actual);
                }
                break;
            }
        } else {
            std.log.debug("Program '{s}' not found in {s}", .{ program_name, path });
            return error.TestProgramNotFound;
        }
    }
}

const pioz = @import("pioz");
const std = @import("std");
