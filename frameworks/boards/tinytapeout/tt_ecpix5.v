/*

Copyright 2019, (C) Sylvain Lefebvre and contributors
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

// for tinytapeout we target ice40, but then replace SB_IO cells
// by a custom implementation
`define ICE40 1
$$ICE40=1
`define SIM_SB_IO 1
$$SIM_SB_IO=1

`default_nettype none
$$HARDWARE = 1
$$NUM_LEDS = 12
$$color_depth=6
$$color_max  =63
// config
$$config['dualport_bram_supported'] = 'yes'
// declare package pins (has to match the hardware pin definition)
// pin.NAME = <WIDTH>
$$pin.leds=12
$$pin.uart_rx=1
$$pin.uart_tx=1
$$pin.P0A1=1 pin.P0A2=1 pin.P0A3=1 pin.P0A4=1
$$pin.P0A7=1 pin.P0A8=1 pin.P0A9=1 pin.P0A10=1
$$pin.P1A1=1 pin.P1A2=1 pin.P1A3=1 pin.P1A4=1
$$pin.P1A7=1 pin.P1A8=1 pin.P1A9=1 pin.P1A10=1
$$pin.P2A1=1 pin.P2A2=1 pin.P2A3=1 pin.P2A4=1
$$pin.P2A7=1 pin.P2A8=1 pin.P2A9=1 pin.P2A10=1
// pin groups and renaming
$$pin.video_r   = {pin.P0A4,pin.P0A3,pin.P0A2,pin.P0A1,0,0}
$$pin.video_g   = {pin.P1A4,pin.P1A3,pin.P1A2,pin.P1A1,0,0}
$$pin.video_b   = {pin.P0A10,pin.P0A9,pin.P0A8,pin.P0A7,0,0}
$$pin.video_hs  = {pin.P1A7}
$$pin.video_vs  = {pin.P1A8}
$$pin.ram_clk   = {pin.P2A4} pin.ram_csn   = {pin.P2A1}
$$pin.ram_io0   = {pin.P2A2} pin.ram_io1   = {pin.P2A3}
$$pin.ram_io2   = {pin.P2A7} pin.ram_io3   = {pin.P2A8}
$$pin.ram_bank  = {pin.P2A10,pin.P2A9}

// diamond 3.7 accepts this PLL
// diamond 3.8-3.9 is untested
// diamond 3.10 or higher is likely to abort with error about unable to use feedback signal
// cause of this could be from wrong CPHASE/FPHASE parameters
module pll
(
    input clkin, // 100 MHz, 0 deg
    output clkout0, // 25 MHz, 0 deg
    output locked
);
(* FREQUENCY_PIN_CLKI="100" *)
(* FREQUENCY_PIN_CLKOP="25" *)
(* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
EHXPLLL #(
        .PLLRST_ENA("DISABLED"),
        .INTFB_WAKE("DISABLED"),
        .STDBY_ENABLE("DISABLED"),
        .DPHASE_SOURCE("DISABLED"),
        .OUTDIVIDER_MUXA("DIVA"),
        .OUTDIVIDER_MUXB("DIVB"),
        .OUTDIVIDER_MUXC("DIVC"),
        .OUTDIVIDER_MUXD("DIVD"),
        .CLKI_DIV(4),
        .CLKOP_ENABLE("ENABLED"),
        .CLKOP_DIV(24),
        .CLKOP_CPHASE(11),
        .CLKOP_FPHASE(0),
        .FEEDBK_PATH("CLKOP"),
        .CLKFB_DIV(1)
    ) pll_i (
        .RST(1'b0),
        .STDBY(1'b0),
        .CLKI(clkin),
        .CLKOP(clkout0),
        .CLKFB(clkout0),
        .CLKINTFB(),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b1),
        .PHASESTEP(1'b1),
        .PHASELOADREG(1'b1),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(1'b0),
        .LOCK(locked)
	);
endmodule

module top(
  %TOP_SIGNATURE%
  input  clk100
  );

reg ready = 0;

reg [31:0] RST_d;
reg [31:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge clk25) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 32'b111111111111111111111111111111;
  end
end

wire run_main;
assign run_main = 1'b1;

wire design_clk;

wire clk25;
pll _pll(.clkin(clk100),.clkout0(clk25));

%WIRE_DECL%

M_main __main(
  .clock    (clk25),
  .out_clock(design_clk),
  .reset    (RST_q[0]),
  %MAIN_GLUE%
  .in_run   (run_main)
);

endmodule
