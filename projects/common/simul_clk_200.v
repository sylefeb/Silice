module simul_clk_200
(
    output clkout0 // 200 MHz
);

reg clk;

assign clkout0 = clk;

initial begin
  clk   = 1'b0;
  forever clk = #2.5 ~clk; // generates a 200 MHz clock
end

endmodule
