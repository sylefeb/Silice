module sdram_clock (
        input  clk,
        output sdram_clk
    );

`ifdef MOJO

    // This is used to drive the SDRAM clock
    wire sdram_clk_ddr;
    
    ODDR2 #(
        .DDR_ALIGNMENT("NONE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) ODDR2_inst (
        .Q(sdram_clk_ddr), // 1-bit DDR output data
        .C0(clk), // 1-bit clock input
        .C1(~clk), // 1-bit clock input
        .CE(1'b1), // 1-bit clock enable input
        .D0(1'b0), // 1-bit data input (associated with C0)
        .D1(1'b1), // 1-bit data input (associated with C1)
        .R(1'b0), // 1-bit reset input
        .S(1'b0) // 1-bit set input
    );
    
    IODELAY2 #(
        .IDELAY_VALUE(0),
        .IDELAY_MODE("NORMAL"),
        .ODELAY_VALUE(100), // value of 100 seems to work at 100MHz
        .IDELAY_TYPE("FIXED"),
        .DELAY_SRC("ODATAIN"),
        .DATA_RATE("SDR")
    ) IODELAY_inst (
        .IDATAIN(1'b0),
        .T(1'b0),
        .ODATAIN(sdram_clk_ddr),
        .CAL(1'b0),
        .IOCLK0(1'b0),
        .IOCLK1(1'b0),
        .CLK(1'b0),
        .INC(1'b0),
        .CE(1'b0),
        .RST(1'b0),
        .BUSY(),
        .DATAOUT(),
        .DATAOUT2(),
        .TOUT(),
        .DOUT(sdram_clk)
    );
    
`else

`ifdef DE10NANO
    
    altddio_out
    #(
      .extend_oe_disable("OFF"),
      .intended_device_family("Cyclone V"),
      .invert_output("OFF"),
      .lpm_hint("UNUSED"),
      .lpm_type("altddio_out"),
      .oe_reg("UNREGISTERED"),
      .power_up_high("OFF"),
      .width(1)
    )
    sdramclk_ddr
    (
      .datain_h(1'b0),
      .datain_l(1'b1),
      .outclock(clk),
      .dataout(sdram_clk),
      .aclr(1'b0),
      .aset(1'b0),
      .oe(1'b1),
      .outclocken(1'b1),
      .sclr(1'b0),
      .sset(1'b0)
    );

`else

    assign sdram_clk = ~clk;
    
`endif
`endif
    
endmodule
