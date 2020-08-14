module simul_clk_166
(
    output clkout0 // 166 MHz
);

reg clk;

assign clkout0 = clk;

initial begin
  clk   = 1'b0;
  forever clk = #3 ~clk;
end

endmodule
