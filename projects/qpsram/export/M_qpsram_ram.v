/*
[Bare framework] Leave empty, this is used when exporting to verilog
*/

// SL 2021-12-12
// produces an inverted clock of same frequency through DDR primitives
module ddr_clock(
        input  clock,
        input  enable,
        output ddr_clock
    );

`ifdef ICARUS
  reg renable;
  reg rddr_clock;
  always @(posedge clock) begin
    rddr_clock <= 0;
    renable    <= enable;
  end
  always @(negedge clock) begin
    rddr_clock <= renable;
  end
  assign ddr_clock = rddr_clock;
`endif

`ifdef ICE40
  SB_IO #(
    .PIN_TYPE(6'b1100_11)
  ) sbio_clk (
      .PACKAGE_PIN(ddr_clock),
      .D_OUT_0(1'b0),
      .D_OUT_1(1'b1),
      .OUTPUT_ENABLE(enable),
      .OUTPUT_CLK(clock)
  );
`endif

endmodule


module sb_io_inout(
  input        clock,
	input        oe,
  input        out,
	output       in,
  inout        pin
  );

  SB_IO #(
    // .PIN_TYPE(6'b1010_00) // not registered
    .PIN_TYPE(6'b1101_00) // registered
  ) sbio (
      .PACKAGE_PIN(pin),
			.OUTPUT_ENABLE(oe),
      .D_OUT_0(out),
      //.D_OUT_1(out),
			.D_IN_1(in),
      .OUTPUT_CLK(clock),
      .INPUT_CLK(clock)
  );

endmodule

// http://www.latticesemi.com/~/media/LatticeSemi/Documents/TechnicalBriefs/SBTICETechnologyLibrary201504.pdf


module sb_io(
  input        clock,
  input        out,
  output       pin
  );

  SB_IO #(
    .PIN_TYPE(6'b0101_00)
    //                ^^ ignored (input)
    //           ^^^^ registered output
  ) sbio (
      .PACKAGE_PIN(pin),
      .D_OUT_0(out),
      .OUTPUT_CLK(clock)
  );

endmodule

// http://www.latticesemi.com/~/media/LatticeSemi/Documents/TechnicalBriefs/SBTICETechnologyLibrary201504.pdf


module M_qpsram_qspi_M_qpsram_ram_spi (
in_send,
in_trigger,
in_send_else_read,
out_read,
out_clk,
out_csn,
inout_io0,
inout_io1,
inout_io2,
inout_io3,
reset,
out_clock,
clock
);
input  [7:0] in_send;
input  [0:0] in_trigger;
input  [0:0] in_send_else_read;
output  [7:0] out_read;
output  [0:0] out_clk;
output  [0:0] out_csn;
inout  [0:0] inout_io0;
inout  [0:0] inout_io1;
inout  [0:0] inout_io2;
inout  [0:0] inout_io3;
input reset;
output out_clock;
input clock;
assign out_clock = clock;
wire  [0:0] _w_ddr_clock_unnamed_0_ddr_clock;
wire  [0:0] _w_sb_io0_in;
wire  [0:0] _w_sb_io1_in;
wire  [0:0] _w_sb_io2_in;
wire  [0:0] _w_sb_io3_in;
reg  [3:0] _t_io_oe;
reg  [3:0] _t_io_o;
wire  [0:0] _w_nenable;

reg  [7:0] _d_sending = 0;
reg  [7:0] _q_sending = 0;
reg  [0:0] _d_osc = 0;
reg  [0:0] _q_osc = 0;
reg  [0:0] _d_enable = 0;
reg  [0:0] _q_enable = 0;
reg  [7:0] _d_read;
reg  [7:0] _q_read;
reg  [0:0] _d_csn = 1;
reg  [0:0] _q_csn = 1;
assign out_read = _q_read;
assign out_clk = _w_ddr_clock_unnamed_0_ddr_clock;
assign out_csn = _q_csn;
ddr_clock ddr_clock_unnamed_0 (
.clock(clock),
.enable(_q_enable),
.ddr_clock(_w_ddr_clock_unnamed_0_ddr_clock));
sb_io_inout sb_io0 (
.clock(clock),
.oe(_t_io_oe[0+:1]),
.out(_t_io_o[0+:1]),
.in(_w_sb_io0_in),
.pin(inout_io0));
sb_io_inout sb_io1 (
.clock(clock),
.oe(_t_io_oe[1+:1]),
.out(_t_io_o[1+:1]),
.in(_w_sb_io1_in),
.pin(inout_io1));
sb_io_inout sb_io2 (
.clock(clock),
.oe(_t_io_oe[2+:1]),
.out(_t_io_o[2+:1]),
.in(_w_sb_io2_in),
.pin(inout_io2));
sb_io_inout sb_io3 (
.clock(clock),
.oe(_t_io_oe[3+:1]),
.out(_t_io_o[3+:1]),
.in(_w_sb_io3_in),
.pin(inout_io3));


assign _w_nenable = ~_q_enable;

`ifdef FORMAL
initial begin
assume(reset);
end
`endif
always @* begin
_d_sending = _q_sending;
_d_osc = _q_osc;
_d_enable = _q_enable;
_d_read = _q_read;
_d_csn = _q_csn;
// _always_pre
// __block_1
_d_csn = _w_nenable;

_t_io_oe = {4{in_send_else_read}};

_d_read = {_q_read[0+:4],{_w_sb_io3_in[0+:1],_w_sb_io2_in[0+:1],_w_sb_io1_in[0+:1],_w_sb_io0_in[0+:1]}};

_t_io_o = ~_q_osc ? _q_sending[0+:4]:_q_sending[4+:4];

_d_sending = (~_q_osc|~_q_enable) ? in_send:_q_sending;

_d_osc = ~in_trigger ? 1'b0:~_q_osc;

_d_enable = in_trigger;

// __block_2
// _always_post
// pipeline stage triggers
end

always @(posedge clock) begin
_q_sending <= _d_sending;
_q_osc <= _d_osc;
_q_enable <= _d_enable;
_q_read <= _d_read;
_q_csn <= _d_csn;
end

endmodule


module M_qpsram_ram (
in_in_ready,
in_init,
in_addr,
in_wdata,
in_wenable,
out_rdata,
out_busy,
out_data_next,
out_ram_csn,
out_ram_clk,
inout_ram_io0,
inout_ram_io1,
inout_ram_io2,
inout_ram_io3,
in_run,
out_done,
reset,
out_clock,
clock
);
input  [0:0] in_in_ready;
input  [0:0] in_init;
input  [23:0] in_addr;
input  [7:0] in_wdata;
input  [0:0] in_wenable;
output  [7:0] out_rdata;
output  [0:0] out_busy;
output  [0:0] out_data_next;
output  [0:0] out_ram_csn;
output  [0:0] out_ram_clk;
inout  [0:0] inout_ram_io0;
inout  [0:0] inout_ram_io1;
inout  [0:0] inout_ram_io2;
inout  [0:0] inout_ram_io3;
input in_run;
output out_done;
input reset;
output out_clock;
input clock;
assign out_clock = clock;
wire  [7:0] _w_spi_read;
wire  [0:0] _w_spi_clk;
wire  [0:0] _w_spi_csn;
reg  [0:0] _t_accept_in;

reg  [31:0] _d_sendvec = 0;
reg  [31:0] _q_sendvec = 0;
reg  [7:0] _d__spi_send;
reg  [7:0] _q__spi_send;
reg  [0:0] _d__spi_trigger;
reg  [0:0] _q__spi_trigger;
reg  [0:0] _d__spi_send_else_read;
reg  [0:0] _q__spi_send_else_read;
reg  [4:0] _d_wait = 0;
reg  [4:0] _q_wait = 0;
reg  [4:0] _d_sending = 0;
reg  [4:0] _q_sending = 0;
reg  [2:0] _d_stage = 1;
reg  [2:0] _q_stage = 1;
reg  [2:0] _d_after = 0;
reg  [2:0] _q_after = 0;
reg  [0:0] _d_send_else_read = 0;
reg  [0:0] _q_send_else_read = 0;
reg  [0:0] _d_continue = 0;
reg  [0:0] _q_continue = 0;
reg  [7:0] _d_rdata;
reg  [7:0] _q_rdata;
reg  [0:0] _d_busy = 0;
reg  [0:0] _q_busy = 0;
reg  [0:0] _d_data_next = 0;
reg  [0:0] _q_data_next = 0;
assign out_rdata = _q_rdata;
assign out_busy = _q_busy;
assign out_data_next = _q_data_next;
assign out_ram_csn = _w_spi_csn;
assign out_ram_clk = _w_spi_clk;
assign out_done = 0;
M_qpsram_qspi_M_qpsram_ram_spi spi (
.in_send(_q__spi_send),
.in_trigger(_q__spi_trigger),
.in_send_else_read(_q__spi_send_else_read),
.out_read(_w_spi_read),
.out_clk(_w_spi_clk),
.out_csn(_w_spi_csn),
.inout_io0(inout_ram_io0),
.inout_io1(inout_ram_io1),
.inout_io2(inout_ram_io2),
.inout_io3(inout_ram_io3),
.reset(reset),
.clock(clock));



`ifdef FORMAL
initial begin
assume(reset);
end
`endif
always @* begin
_d_sendvec = _q_sendvec;
_d__spi_send = _q__spi_send;
_d__spi_trigger = _q__spi_trigger;
_d__spi_send_else_read = _q__spi_send_else_read;
_d_wait = _q_wait;
_d_sending = _q_sending;
_d_stage = _q_stage;
_d_after = _q_after;
_d_send_else_read = _q_send_else_read;
_d_continue = _q_continue;
_d_rdata = _q_rdata;
_d_busy = _q_busy;
_d_data_next = _q_data_next;
// _always_pre
// __block_1
_d__spi_send_else_read = _q_send_else_read;

_t_accept_in = 0;

_d_data_next = 0;

_d_continue = _q_continue&in_in_ready;

  case (_q_stage)
  0: begin
// __block_3_case
// __block_4
_d_stage = _q_wait[4+:1] ? _q_after:0;

_d_wait = _q_wait+1;

// __block_5
  end
  1: begin
// __block_6_case
// __block_7
_t_accept_in = 1;

// __block_8
  end
  2: begin
// __block_9_case
// __block_10
_d__spi_trigger = 1;

_d__spi_send = _q_sendvec[24+:8];

_d_sendvec = {_q_sendvec[0+:24],8'b0};

_d_stage = 0;

_d_wait = 16;

_d_after = _q_sending[0+:1] ? 3:2;

_d_sending = _q_sending>>1;

// __block_11
  end
  3: begin
// __block_12_case
// __block_13
_d_send_else_read = in_wenable;

_d__spi_trigger = ~in_init;

_d__spi_send = in_wdata;

_d_data_next = in_wenable;

_d_stage = 0;

_d_wait = in_wenable ? 16:7;

_d_after = 4;

// __block_14
  end
  4: begin
// __block_15_case
// __block_16
_d_rdata = _w_spi_read;

_d_data_next = 1;

_d__spi_trigger = _d_continue;

_d__spi_send = in_wdata;

_d_busy = _d_continue;

_d_wait = 16;

_d_stage = ~_d_continue ? 1:0;

_d_after = 4;

_t_accept_in = ~_d_continue;

// __block_17
  end
endcase
// __block_2
if ((in_in_ready|in_init)&_t_accept_in&~reset) begin
// __block_18
// __block_20
_d_sending = 5'b01000;

_d_sendvec = in_init ? {32'b00000000000100010000000100000001}:{in_wenable ? 8'h02:8'hEB,in_addr};

_d_send_else_read = 1;

_d_busy = 1;

_d_stage = 2;

_d_continue = 1;

// __block_21
end else begin
// __block_19
end
// 'after'
// __block_22
// __block_23
// _always_post
// pipeline stage triggers
end

always @(posedge clock) begin
_q_sendvec <= _d_sendvec;
_q__spi_send <= _d__spi_send;
_q__spi_trigger <= _d__spi_trigger;
_q__spi_send_else_read <= _d__spi_send_else_read;
_q_wait <= _d_wait;
_q_sending <= _d_sending;
_q_stage <= _d_stage;
_q_after <= _d_after;
_q_send_else_read <= _d_send_else_read;
_q_continue <= _d_continue;
_q_rdata <= _d_rdata;
_q_busy <= _d_busy;
_q_data_next <= _d_data_next;
end

endmodule

