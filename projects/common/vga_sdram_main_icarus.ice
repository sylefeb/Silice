// SL 2019-10

// SDRAM controller
import('sdram_icarus.v')

// SDRAM simulator
append('mt48lc32m8a2.v')
import('simul_sdram.v')

// Frame buffer row
import('dual_frame_buffer_row.v')

// VGA driver
$include('vga.ice')
$include('vga_sdram.ice')

// ------------------------- 

// PLL for simulation
/*
NOTE: sdram_clock cannot use a normal output as this would mean sampling
      a register tracking clock using clock itself; this lead to a race
	  condition, see https://stackoverflow.com/questions/58563770/unexpected-simulation-behavior-in-iverilog-on-flip-flop-replicating-clock-signal
	  
*/
algorithm pll(
  output  uint1 vga_clock,
  output  uint1 vga_reset,
  output! uint1 sdram_clock,
  output! uint1 sdram_reset
) <autorun>
{
  uint3 counter = 0;
  uint8 trigger = 8b11111111;
  
  sdram_clock   := clock;
  sdram_reset   := reset;
  
  vga_clock     := counter[2,1];
  vga_reset     := (trigger > 0);
  
  while (1) {
	counter = counter + 1;
	trigger = trigger >> 1;
  }
}

// ------------------------- 

algorithm main(
  output! uint1 vga_clock,
  output! uint4 vga_r,
  output! uint4 vga_g,
  output! uint4 vga_b,
  output! uint1 vga_hs,
  output! uint1 vga_vs
) <@sdram_clock> {

// --- PLL

uint1 vga_reset   = 0;
uint1 sdram_clock = 0;
uint1 sdram_reset = 0;

pll clockgen<@clock,!reset>(
  vga_clock   :> vga_clock,
  vga_reset   :> vga_reset,
  sdram_clock :> sdram_clock,
  sdram_reset :> sdram_reset
);

// --- VGA

uint1  vga_active = 0;
uint1  vga_vblank = 0;
uint10 vga_x  = 0;
uint10 vga_y  = 0;

vga vga_driver<@vga_clock,!vga_reset>(
    vga_hs :> vga_hs,
	vga_vs :> vga_vs,
	active :> vga_active,
	vblank :> vga_vblank,
	vga_x  :> vga_x,
	vga_y  :> vga_y
);

// --- SDRAM

uint23 saddr       = 0;
uint1  srw         = 0;
uint32 sdata_in    = 0;
uint32 sdata_out   = 0;
uint1  sbusy       = 0;
uint1  sin_valid   = 0;
uint1  sout_valid  = 0;

uint1  sdram_cle   = 0;
uint1  sdram_dqm   = 0;
uint1  sdram_cs    = 0;
uint1  sdram_we    = 0;
uint1  sdram_cas   = 0;
uint1  sdram_ras   = 0;
uint2  sdram_ba    = 0;
uint13 sdram_a     = 0;
uint8  sdram_dq    = 0;

simul_sdram simul<@sdram_clock,!sdram_reset>(
  sdram_clk <: clock,
  <:auto:>
);

sdram memory<@sdram_clock,!sdram_reset>(
  clk       <: clock,
  rst       <: reset,
  addr      <: saddr,
  rw        <: srw,
  data_in   <: sdata_in,
  data_out  :> sdata_out,
  busy      :> sbusy,
  in_valid  <: sin_valid,
  out_valid :> sout_valid,
  <:auto:> // TODO FIXME only way to bind inout? introduce <:> ?
);

// --- SDRAM switcher

uint23 saddr0      = 0;
uint1  srw0        = 0;
uint32 sd_in0      = 0;
uint32 sd_out0     = 0;
uint1  sbusy0      = 0;
uint1  sin_valid0  = 0;
uint1  sout_valid0 = 0;

uint23 saddr1      = 0;
uint1  srw1        = 0;
uint32 sd_in1      = 0;
uint32 sd_out1     = 0;
uint1  sbusy1      = 0;
uint1  sin_valid1  = 0;
uint1  sout_valid1 = 0;

uint1  select      = 0;

sdram_switcher sd_switcher<@sdram_clock,!sdram_reset>(
  select     <: select,

  saddr      :> saddr,
  srw        :> srw,
  sd_in      :> sdata_in,
  sd_out     <: sdata_out,
  sbusy      <: sbusy,
  sin_valid  :> sin_valid,
  sout_valid <: sout_valid,

  saddr0      <: saddr0,
  srw0        <: srw0,
  sd_in0      <: sd_in0,
  sd_out0     :> sd_out0,
  sbusy0      :> sbusy0,
  sin_valid0  <: sin_valid0,
  sout_valid0 :> sout_valid0,

  saddr1      <: saddr1,
  srw1        <: srw1,
  sd_in1      <: sd_in1,
  sd_out1     :> sd_out1,
  sbusy1      :> sbusy1,
  sin_valid1  <: sin_valid1,
  sout_valid1 :> sout_valid1
);

// --- Frame buffer row memory
// dual clock crosses from sdram to vga

  uint16 pixaddr_r = 0;
  uint16 pixaddr_w = 0;
  uint32 pixdata_r = 0;
  uint32 pixdata_w = 0;
  uint1  pixwenable  = 0;

  dual_frame_buffer_row fbr(
    rclk    <: vga_clock,
    wclk    <: sdram_clock,
    raddr   <: pixaddr_r,
    rdata   :> pixdata_r,
    waddr   <: pixaddr_w,
    wdata   <: pixdata_w,
    wenable <: pixwenable
  );

// --- Display

  uint1 row_busy = 0;

  frame_display display<@vga_clock,!vga_reset>(
    pixaddr   :> pixaddr_r,
    pixdata_r <: pixdata_r,
    row_busy :> row_busy,
	vga_x <: vga_x,
	vga_y <: vga_y,
    <:auto:>
  );

// --- Frame buffer row updater
  frame_buffer_row_updater fbrupd<@sdram_clock,!sdram_reset>(
    working    :> select,
    pixaddr    :> pixaddr_w,
    pixdata_w  :> pixdata_w,
    pixwenable :> pixwenable,
    row_busy   <: row_busy,
    vsync      <: vga_vblank,
    saddr      :> saddr0,
    srw        :> srw0,
    sdata_in   :> sd_in0,
    sdata_out  <: sd_out0,
    sbusy      <: sbusy0,
    sin_valid  :> sin_valid0,
    sout_valid <: sout_valid0
  );
 
// --- Frame drawer
  frame_drawer drawer<@sdram_clock,!sdram_reset>(
    vsync      <: vga_vblank,
    saddr      :> saddr1,
    srw        :> srw1,
    sdata_in   :> sd_in1,
    sdata_out  <: sd_out1,
    sbusy      <: sbusy1,
    sin_valid  :> sin_valid1,
    sout_valid <: sout_valid1  
  );

  uint8 frame  = 0;
  uint8 iter   = 0;

  // ---------- let's go

  // start the switcher
  sd_switcher <- ();
  
  // start the frame drawer
  drawer <- ();
   
  // start the frame buffer row updater
  fbrupd <- ();
 
  // we count a number of frames and stop
  while (frame < 5) {
  
    while (vga_vblank == 1) { }
	  $display("vblank off");
    
	  while (vga_vblank == 0) { }
    $display("vblank on");
	
    frame = frame + 1;

  }

}

// ------------------------- 
