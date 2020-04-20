module reset_conditioner (
    input rcclk,
    input in,
    output reg out
  );  
  reg [7:0] counter_d,counter_q;
  always @* begin
    counter_d = counter_q;
    if (counter_q == 0) begin
      out = 0;
    end else begin
      out = 1;
      counter_d = counter_q + 1;
    end
  end  
  always @(posedge rcclk) begin
    if (in == 1'b1) begin
      counter_q <= 1;
    end else begin
      counter_q <= counter_d;
    end
  end 
endmodule
