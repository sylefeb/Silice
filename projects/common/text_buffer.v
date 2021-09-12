module text_buffer(
    input            clk,
    input [13:0]     addr,
    input [5:0]      wdata,
    input            wenable,   
    output reg [5:0] rdata
  );
  
  reg [5:0] buffer [12799:0]; // 80x160 letter indices
  
  always @(posedge clk) begin
    rdata <= buffer[addr];
    if (wenable) begin
      buffer[addr] <= wdata;
    end
  end
  
endmodule
