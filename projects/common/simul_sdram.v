module simul_sdram(
    input sdram_clk,
    input sdram_cle,
    input [1:0]  sdram_dqm,
    input sdram_cs,
    input sdram_we,
    input sdram_cas,
    input sdram_ras,
    input [1:0]  sdram_ba,
    input [12:0] sdram_a,
	  inout [15:0] sdram_dq);

mt48lc16m16a2 simulator(
  .Dq(sdram_dq),
  .Addr(sdram_a),
  .Ba(sdram_ba),
  .Clk(sdram_clk),
  .Cke(sdram_cle),
  .Cs_n(sdram_cs),
  .Ras_n(sdram_ras),
  .Cas_n(sdram_cas),
  .We_n(sdram_we),
  .Dqm(sdram_dqm)
);

endmodule
