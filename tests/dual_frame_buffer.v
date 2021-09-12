module dual_frame_buffer(
    input            rclk,
    input [15:0]     raddr,
    output reg [3:0] rdata,
    input            wclk,
    input [15:0]     waddr,
    input [3:0]      wdata,
    input            wenable
  );
  
  reg [3:0] buffer [63999:0];
  
  always @(posedge rclk) begin
    rdata <= buffer[raddr];
  end
  
  always @(posedge wclk) begin 
    if (wenable) begin
      buffer[waddr] <= wdata;
    end
  end
  
endmodule
