module ice40_bram(
	input         clock,
  input  [7:0]  waddr,
  input  [15:0] wdata,
  input  [15:0] wmask,
  input         wenable,
  input  [7:0]  raddr,
  output [15:0] rdata
	);

(* BEL="X19/Y5/ram" *)
SB_RAM40_4K #(.WRITE_MODE(0),.READ_MODE(0),
    .INIT_0(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),                 
    .INIT_1(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),                 
    .INIT_2(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),                 
    .INIT_3(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),                 
    .INIT_4(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),                 
    .INIT_5(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),                 
    .INIT_6(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),                 
    .INIT_7(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),                 
    .INIT_8(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),                 
    .INIT_9(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),                 
    .INIT_A(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),                 
    .INIT_B(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),                 
    .INIT_C(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),                 
    .INIT_D(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),                 
    .INIT_E(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),                 
    .INIT_F(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx)
) bram (
    .WDATA(wdata),
    .MASK(wmask),
    .WADDR(waddr),
    .WE(wenable),
    .WCLKE(1'b1),
    .WCLK(clock),
    .RDATA(rdata),
    .RADDR(raddr),
    .RE(1'b1),
    .RCLKE(1'b1),
    .RCLK(clock)
);

endmodule
