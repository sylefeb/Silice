module dual_text_buffer(
    input            rclk,
    input [13:0]     raddr,
    output reg [5:0] rdata,
    input            wclk,
    input [13:0]     waddr,
    input [5:0]      wdata,
    input            wenable
  );
  
  reg [5:0] buffer [14399:0];
  
  always @(posedge rclk) begin
    rdata <= buffer[raddr];
  end
  
  always @(posedge wclk) begin 
    if (wenable) begin
      buffer[waddr] <= wdata;
    end
  end
  
endmodule
