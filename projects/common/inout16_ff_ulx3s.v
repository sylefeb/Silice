module inout16_ff_ulx3s(     
  inout  [15:0] io_pin,
  input  [15:0] io_write,
  output [15:0] io_read,
  input         io_write_enable,
  input         clock
);

  wire [15:0] btw;
  BB       db_buf[15:0] (.I(io_write), .O(btw), .B(io_pin),  .T({16{~io_write_enable}}));
  IFS1P3BX dbi_ff[15:0] (.D(btw), .Q(io_read), .SCLK(clock), .PD({16{io_write_enable}}));

endmodule
