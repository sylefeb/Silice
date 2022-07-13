/*

Copyright 2019, (C) Gwenhael Goavec-Mero, Sylvain Lefebvre and contributors
List contributors with: git shortlog -n -s -- <filename>

MIT license

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

(header_2_M)

*/
`define MCH2022 1
`define ICE40 1
`default_nettype none
$$MCH2022=1
$$ICE40=1
$$HARDWARE=1
$$NUM_LEDS=3
$$NUM_BTNS=3
$$color_depth=6
$$color_max  =63
$$config['bram_wenable_width'] = '1'
$$config['dualport_bram_wenable0_width'] = '1'
$$config['dualport_bram_wenable1_width'] = '1'
$$config['simple_dualport_bram_wenable0_width'] = '1'
$$config['simple_dualport_bram_wenable1_width'] = '1'

module top(
  output [2:0] rgb,
`ifdef UART
  output uart_tx,
  input  uart_rx,
`endif
`ifdef LCD
  output [7:0] lcd_d,
  output lcd_rs,
  output lcd_wr_n,
  output lcd_cs_n,
  output lcd_rst_n,
  input  lcd_mode,
  input  lcd_fmark,
`endif
`ifdef PSRAM
  inout  [3:0] ram_io,
  output       ram_clk,
  output       ram_cs_n,
`endif
`ifdef ESPSPI
  input  spi_mosi,
  output spi_miso,
  input  spi_clk,
  input  spi_cs_n,
  output irq_n,
`endif
  input  clk_in
  );

// clock from design is used in case
// it relies on a PLL: in such cases
// we cannot use the clock fed into
// the PLL here
wire design_clk;

reg ready = 0;
reg [15:0] RST_d;
reg [15:0] RST_q;

always @* begin
  RST_d = RST_q[15] ? RST_q : RST_q + 1;
end

always @(posedge design_clk) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 0;
  end
end

wire [2:0] __main_leds;

wire   run_main;
assign run_main = 1'b1;

M_main __main(
  .clock(clk_in),
  .out_clock(design_clk),
  .reset(~RST_q[15]),
  .out_leds(__main_leds),
`ifdef UART
  .out_uart_tx(uart_tx),
  .in_uart_rx(uart_rx),
`endif
`ifdef LCD
  .out_lcd_d(lcd_d),
  .out_lcd_rs(lcd_rs),
  .out_lcd_wr_n(lcd_wr_n),
  .out_lcd_cs_n(lcd_cs_n),
  .out_lcd_rst_n(lcd_rst_n),
  .in_lcd_mode(lcd_mode),
  .in_lcd_fmark(lcd_fmark),
`endif
`ifdef PSRAM
  .inout_ram_io0(ram_io[0]),
  .inout_ram_io1(ram_io[1]),
  .inout_ram_io2(ram_io[2]),
  .inout_ram_io3(ram_io[3]),
  .out_ram_clk(ram_clk),
  .out_ram_csn(ram_cs_n),
`endif
`ifdef ESPSPI
  .in_espspi_mosi(spi_mosi),
  .out_espspi_miso(spi_miso),
  .in_espspi_clk(spi_clk),
  .in_espspi_cs_n(spi_cs_n),
  .out_espirq_n(irq_n),
`endif
  .in_run(run_main)
);

// Using current-limited outputs, see note here:
// https://github.com/badgeteam/mch2022-firmware-ice40/blob/43c77cfc5e1fd4599ca16852cd9c087b396fc651/projects/Fading-RGB/rtl/fading_rgb.v#L20-L29

SB_RGBA_DRV #(
      .CURRENT_MODE("0b1"),       // half current
      .RGB0_CURRENT("0b000011"),  // 4 mA
      .RGB1_CURRENT("0b000011"),  // 4 mA
      .RGB2_CURRENT("0b000011")   // 4 mA
) RGBA_DRIVER (
      .CURREN(1'b1),
      .RGBLEDEN(1'b1),
      .RGB1PWM(__main_leds[0]),
      .RGB2PWM(__main_leds[1]),
      .RGB0PWM(__main_leds[2]),
      .RGB0(rgb[0]),
      .RGB1(rgb[1]),
      .RGB2(rgb[2])
);

endmodule
