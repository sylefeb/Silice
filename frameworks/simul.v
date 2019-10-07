reg clk;
reg rst_n;

initial begin
  clk = 1'b0;
  rst_n = 1'b0;
  repeat(4) #10 clk = ~clk;
  rst_n = 1'b1;
  forever #10 clk = ~clk; // generate a clock
end
