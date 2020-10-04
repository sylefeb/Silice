module inout16_set(     
  inout  [15:0] io_pin,
  input  [15:0] io_write,
  output [15:0] io_read,
  input         io_write_enable
);
  assign io_pin  = io_write_enable ? io_write : 16'hZZ;
  assign io_read = io_pin; 
endmodule
