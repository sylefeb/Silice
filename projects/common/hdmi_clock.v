module hdmi_clock (
        input  clk,
        input  rst,
        output pixel_clk,     // 25 MHz
        output half_hdmi_clk  // 125 MHz
    );

`ifdef MOJO

mojo_clk_50_25_125_125n mclk(
  .CLK_IN1(clk),
  .CLK_OUT2(pixel_clk),
  .CLK_OUT3(half_hdmi_clk),
  .CLK_OUT4(half_hdmi_clk_n),
  .RESET(rst)
);

`else

`ifdef DE10NANO

// not yet implemented

`else

`ifdef ECP5

wire clkfb;
wire clkos;
wire clkout0;
wire clkout2;
wire locked;

(* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
EHXPLLL #(
        .PLLRST_ENA("DISABLED"),
        .INTFB_WAKE("DISABLED"),
        .STDBY_ENABLE("DISABLED"),
        .DPHASE_SOURCE("DISABLED"),
        .CLKOP_FPHASE(0),
        .CLKOP_CPHASE(0),
        .OUTDIVIDER_MUXA("DIVA"),
        .CLKOP_ENABLE("ENABLED"),
        .CLKOP_DIV(2),
        .CLKOS_ENABLE("ENABLED"),
        .CLKOS_DIV(4),
        .CLKOS_CPHASE(0),
        .CLKOS_FPHASE(0),
        .CLKOS2_ENABLE("ENABLED"),
        .CLKOS2_DIV(20),
        .CLKOS2_CPHASE(0),
        .CLKOS2_FPHASE(0),
        .CLKFB_DIV(10),
        .CLKI_DIV(1),
        .FEEDBK_PATH("INT_OP")
    ) pll_i (
        .CLKI(clk),
        .CLKFB(clkfb),
        .CLKINTFB(clkfb),
        .CLKOP(clkout0), // 250
        .CLKOS(half_hdmi_clk),  // 125
        .CLKOS2(clkout2), // 25
        .RST(1'b0),
        .STDBY(1'b0),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b0),
        .PHASESTEP(1'b0),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(1'b0),
        .LOCK(locked)
	);

assign pixel_clk = clk;

`else

`ifdef ICARUS

reg genclk;

initial begin
  genclk = 1'b0;
  forever #4 genclk = ~genclk;   // generates a 125 MHz clock
end

assign half_hdmi_clk = genclk;
assign pixel_clk     = clk;

`endif
    
`endif
`endif
`endif
    
endmodule
