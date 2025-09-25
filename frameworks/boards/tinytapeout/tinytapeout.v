/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

/* verilator lint_off DECLFILENAME */
/* verilator lint_off PINCONNECTEMPTY */

`default_nettype none

// for tinytapeout we target ice40, but then replace SB_IO cells
// by a custom implementation
`define ICE40 1
$$ICE40=1
`define SIM_SB_IO 1
$$SIM_SB_IO=1

module %TOP_NAME% (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // https://tinytapeout.com/specs/pinouts/

  // register reset
  reg rst_n_q;
  always @(posedge clk) begin
    rst_n_q <= rst_n;
  end

  wire __unused_out_done;
  wire __unused_out_clock;

  M_main main(

    .in_ui(ui_in),
    .out_uo(uo_out),

    .inout_uio_i(uio_in),
    .inout_uio_o(uio_out),
    .inout_uio_oe(uio_oe),

    .in_run(1'b1),
    .reset(~rst_n_q),
    .clock(clk),

    .out_done (__unused_out_done),
    .out_clock(__unused_out_clock)
  );

  // prevents warning
  wire _unused = &{ena,1'b0};

  //              vvvvv inputs when in reset to allow PMOD external takeover
  // assign uio_oe = rst_n ? {1'b1,1'b1,main_uio_oe[3],main_uio_oe[2],1'b1,main_uio_oe[1],main_uio_oe[0],1'b1} : 8'h00;

endmodule
