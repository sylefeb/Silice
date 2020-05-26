module inout4_set(     
  inout  [3:0] io_pin,
  input  [3:0] io_write,
  output [3:0] io_read,
  input        io_write_enable
);
  assign io_pin  = io_write_enable ? io_write : 4'hZ;
  assign io_read = io_pin;
endmodule
