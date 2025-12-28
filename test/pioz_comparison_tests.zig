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

test "addition"                 { try pioz_comparison("addition.pio"); }
test "apa102"                   { try pioz_comparison("apa102.pio"); }
test "blink"                    { try pioz_comparison("blink.pio"); }
test "clocked_input"            { try pioz_comparison("clocked_input.pio"); }
test "differential_manchester"  { try pioz_comparison("differential_manchester.pio"); }
test "hello"                    { try pioz_comparison("hello.pio"); }
test "hub75"                    { try pioz_comparison("hub75.pio"); }
test "i2c"                      { try pioz_comparison("i2c.pio"); }
test "irq"                      { try pioz_comparison("irq.pio"); }
test "manchester_encoding"      { try pioz_comparison("manchester_encoding.pio"); }
test "movrx"                    { try pioz_comparison("movrx.pio"); }
test "nec_carrier_burst"        { try pioz_comparison("nec_carrier_burst.pio"); }
test "nec_carrier_control"      { try pioz_comparison("nec_carrier_control.pio"); }
test "nec_receive"              { try pioz_comparison("nec_receive.pio"); }
test "pio_serialiser"           { try pioz_comparison("pio_serialiser.pio"); }
test "pwm"                      { try pioz_comparison("pwm.pio"); }
test "quadrature_encoder"       { try pioz_comparison("quadrature_encoder.pio"); }
test "resistor_dac"             { try pioz_comparison("resistor_dac.pio"); }
test "spi"                      { try pioz_comparison("spi.pio"); }
test "squarewave"               { try pioz_comparison("squarewave.pio"); }
test "squarewave_fast"          { try pioz_comparison("squarewave_fast.pio"); }
test "squarewave_wrap"          { try pioz_comparison("squarewave_wrap.pio"); }
test "st7789_lcd"               { try pioz_comparison("st7789_lcd.pio"); }
test "uart_rx"                  { try pioz_comparison("uart_rx.pio"); }
test "uart_tx"                  { try pioz_comparison("uart_tx.pio"); }
test "ws2812"                   { try pioz_comparison("ws2812.pio"); }

fn pioz_comparison(comptime path: []const u8) !void {
    const results = pioz.assemble(@embedFile(root_path ++ path), .{});
    try std.testing.expect(results.programs.len > 0);

    inline for (results.programs) |program| {
        const expected_insns = @field(c, program.name ++ "_program_instructions");
        for (0.., program.instructions, expected_insns) |addr, actual, expected| {
            errdefer std.debug.print("at address {d}\n", .{ addr });
            try std.testing.expectEqual(expected, actual);
        }
    }
}

const pioz = @import("pioz");
const std = @import("std");
