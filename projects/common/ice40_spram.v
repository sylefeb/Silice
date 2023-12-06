`ifndef ICE40_SPRAM
`define ICE40_SPRAM

module ice40_spram(
	input         clock,
  input  [13:0] addr,     // 16K entries
  input  [15:0] data_in,  // 16 bits
  input  [3:0]  wmask,
  input         wenable,
  output [15:0] data_out  // 16 bits
	);

SB_SPRAM256KA spram (
    .ADDRESS(addr),
    .DATAIN(data_in),
    .MASKWREN(wmask),
    .WREN(wenable),
    .CHIPSELECT(1'b1),
    .CLOCK(clock),
    .STANDBY(1'b0),
    .SLEEP(1'b0),
    .POWEROFF(1'b1),
    .DATAOUT(data_out)
);

`endif

endmodule
