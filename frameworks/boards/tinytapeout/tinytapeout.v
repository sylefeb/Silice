/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// for tinytapeout we target ice40, but then replace SB_IO cells
// by a custom implementation
`define ICE40 1
$$ICE40=1
`define SIM_SB_IO 1
$$SIM_SB_IO=1

module tt_um_silice (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  wire D5,D4,D3,D2,D1; // ignored

  wire [3:0] main_uio_oe;

  // https://tinytapeout.com/specs/pinouts/

  M_main main(

    .out_leds({D5,D4,D3,D2,D1}),
    .out_ram_bank({uio_out[7],uio_out[6]}),

    .out_ram_csn(uio_out[0]),
    .out_ram_clk(uio_out[3]),

    .inout_ram_io0_i(uio_in[1]),
    .inout_ram_io0_o(uio_out[1]),
    .inout_ram_io0_oe(main_uio_oe[0]),

    .inout_ram_io1_i(uio_in[2]),
    .inout_ram_io1_o(uio_out[2]),
    .inout_ram_io1_oe(main_uio_oe[1]),

    .inout_ram_io2_i(uio_in[4]),
    .inout_ram_io2_o(uio_out[4]),
    .inout_ram_io2_oe(main_uio_oe[2]),

    .inout_ram_io3_i(uio_in[5]),
    .inout_ram_io3_o(uio_out[5]),
    .inout_ram_io3_oe(main_uio_oe[3]),

    .out_spiscreen_clk(uo_out[1]),
    .out_spiscreen_csn(uo_out[2]),
    .out_spiscreen_dc(uo_out[3]),
    .out_spiscreen_mosi(uo_out[4]),
    .out_spiscreen_resn(uo_out[5]),

    .in_btn_0(ui_in[0]),
    .in_btn_1(ui_in[1]),
    .in_btn_2(ui_in[2]),
    .in_btn_3(ui_in[3]),

    .in_run(1'b1),
    .reset(~rst_n),
    .clock(clk)
  );

  //              vvvvv inputs when in reset to allow PMOD external takeover
  assign uio_oe = rst_n ? {1'b1,1'b1,main_uio_oe[3],main_uio_oe[2],1'b1,main_uio_oe[1],main_uio_oe[0],1'b1} : 8'h00;

  assign uo_out[0] = 0;
  assign uo_out[6] = 0;
  assign uo_out[7] = 0;

endmodule
