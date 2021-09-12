// diamond 3.7 accepts this PLL
// diamond 3.8-3.9 is untested
// diamond 3.10 or higher is likely to abort with error about unable to use feedback signal
// cause of this could be from wrong CPHASE/FPHASE parameters
module ulx3s_clk_160_25_160_160ph60
(
    input clkin, // 25 MHz, 0 deg
    output clkout0, // 160 MHz, 0 deg
    output clkout1, // 25.6 MHz, 0 deg
    output clkout2, // 160 MHz, 0 deg
    output clkout3, // 160 MHz, 56.25 deg
    output locked
);
(* FREQUENCY_PIN_CLKI="25" *)
(* FREQUENCY_PIN_CLKOP="160" *)
(* FREQUENCY_PIN_CLKOS="25.6" *)
(* FREQUENCY_PIN_CLKOS2="160" *)
(* FREQUENCY_PIN_CLKOS3="160" *)
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
        .CLKI_DIV(5),
        .CLKOP_ENABLE("ENABLED"),
        .CLKOP_DIV(4),
        .CLKOP_CPHASE(2),
        .CLKOP_FPHASE(0),
        .CLKOS_ENABLE("ENABLED"),
        .CLKOS_DIV(25),
        .CLKOS_CPHASE(2),
        .CLKOS_FPHASE(0),
        .CLKOS2_ENABLE("ENABLED"),
        .CLKOS2_DIV(4),
        .CLKOS2_CPHASE(2),
        .CLKOS2_FPHASE(0),
        .CLKOS3_ENABLE("ENABLED"),
        .CLKOS3_DIV(4),
        .CLKOS3_CPHASE(2),
        .CLKOS3_FPHASE(5),
        .FEEDBK_PATH("CLKOP"),
        .CLKFB_DIV(32)
    ) pll_i (
        .RST(1'b0),
        .STDBY(1'b0),
        .CLKI(clkin),
        .CLKOP(clkout0),
        .CLKOS(clkout1),
        .CLKOS2(clkout2),
        .CLKOS3(clkout3),
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
