`define MOJO 1
$$MOJO=1
$$HARDWARE=1

module reset_conditioner (
    input rcclk,
    input in,
    output reg out
  );  
  localparam STAGES = 3'h4;  
  reg [3:0] M_stage_d, M_stage_q = 4'hf;  
  always @* begin
    M_stage_d = M_stage_q;
    
    M_stage_d = {M_stage_q[0+2-:3], 1'h0};
    out = M_stage_q[3+0-:1];
  end  
  always @(posedge rcclk) begin
    if (in == 1'b1) begin
      M_stage_q <= 4'hf;
    end else begin
      M_stage_q <= M_stage_d;
    end
  end 
endmodule

module mojo_top(
    // 50MHz clock input
    input clk,
    // Input from reset button (active low)
    input rst_n,
    // Outputs to the 8 onboard LEDs
    output reg [7:0]led
    );

// produce clean reset
reg clean_reset;

wire [1-1:0] __reset_cond_out;
reset_conditioner __reset_cond (
  .rcclk(clk),
  .in(~rst_n),
  .out(__reset_cond_out)
);

wire [7:0] __main_out_led;

M_main __main(
  .clock(clk),
  .reset(clean_reset),
  .out_led(__main_out_led)
);

always @* begin
  clean_reset = __reset_cond_out;
  led         = __main_out_led;
end

endmodule
