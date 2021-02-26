module inout1_set(     
  inout  io_pin,
  input  io_write,
  output io_read,
  input  io_write_enable
);
  assign io_pin  = io_write_enable ? io_write : 1'bZ;
  assign io_read = io_pin;
endmodule
