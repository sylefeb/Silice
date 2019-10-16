module top;

reg clk;
reg rst_n;
reg [3:0] vga_r;
reg [3:0] vga_g;
reg [3:0] vga_b;
reg vga_hs;
reg vga_vs;

wire [3:0] __main_vga_r;
wire [3:0] __main_vga_g;
wire [3:0] __main_vga_b;
wire __main_vga_hs;
wire __main_vga_vs;

initial begin
  clk = 1'b0;
  rst_n = 1'b0;
  $display("icarus framework started");
  $dumpfile("icarus.vcd");
  $dumpvars(0,top);
  repeat(4) #5 clk = ~clk;
  rst_n = 1'b1;
  forever #5 clk = ~clk; // generate a clock
end

reg ready = 0;
reg [3:0] RST_d;
reg [3:0] RST_q;

always @* begin
  RST_d = RST_q >> 1;
end

always @(posedge clk) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 4'b1111;
  end
end

wire run_main;
assign run_main = 1'b1;
wire done_main;

M_main __main(
  .clock(clk),
  .reset(RST_d[0]),
  .out_vga_r(__main_vga_r),
  .out_vga_g(__main_vga_g),
  .out_vga_b(__main_vga_b),
  .out_vga_hs(__main_vga_hs),
  .out_vga_vs(__main_vga_vs),  
  .in_run(run_main),
  .out_done(done_main)
);

assign vga_r  = __main_vga_r;
assign vga_g  = __main_vga_g;
assign vga_b  = __main_vga_b;
assign vga_hs = __main_vga_hs;
assign vga_vs = __main_vga_vs;

always @* begin
  if (done_main && !RST_d[0]) $finish;
end

endmodule

