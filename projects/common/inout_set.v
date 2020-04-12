module inout_set(     
  inout  [7:0] io_pin,
  input  [7:0] io_write,
  output [7:0] io_read,
  input        io_write_enable
);

  assign io_pin  = io_write_enable ? io_write : 8'hZZ;
  assign io_read = io_pin;

endmodule
