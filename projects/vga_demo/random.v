module random(input clock,output reg [11:0] rnd);
  wire [11:0] osc;
  metastable_oscillator m_osc[11:0] (.metastable(osc));
  always @(posedge clock) begin
    rnd <= osc;
  end
endmodule
