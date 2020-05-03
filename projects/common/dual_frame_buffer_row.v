module dual_frame_buffer_row(
    input             rclk,
    input [9:0]       raddr,
    output reg [31:0] rdata,
    input             renable,
    input             wclk,
    input [9:0]       waddr,
    input [31:0]      wdata,
    input             wenable
  );
  
  reg [31:0] buffer [79:0]; // 320 / 4, RGB
  
  always @(posedge rclk) begin
    if (renable) begin
      rdata <= buffer[raddr];
    end
  end
  
  always @(posedge wclk) begin 
    if (wenable) begin
      buffer[waddr] <= wdata;
    end
  end
  
endmodule
