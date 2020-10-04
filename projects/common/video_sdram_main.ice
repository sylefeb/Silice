// SL 2019-10

$$if ICARUS then
  // SDRAM simulator
  append('mt48lc16m16a2.v')
  import('simul_sdram.v')
$$end

$$if VGA then
// VGA driver
$include('vga.ice')
$$end

$$if HDMI then
// HDMI driver
$include('hdmi.ice')
$$end

// ------------------------- 

$$if ICARUS or VERILATOR then
// PLL for simulation
/*
NOTE: sdram_clock cannot use a normal output as this would mean sampling
      a register tracking clock using clock itself; this lead to a race
	  condition, see https://stackoverflow.com/questions/58563770/unexpected-simulation-behavior-in-iverilog-on-flip-flop-replicating-clock-signal
	  
*/
algorithm pll(
  output  uint1 video_clock,
  output  uint1 video_reset,
  output! uint1 sdram_clock,
  output! uint1 sdram_reset,
$$if HAS_COMPUTE_CLOCK then
  output  uint1 compute_clock,
  output  uint1 compute_reset
$$end
) <autorun>
{
  uint3 counter = 0;
  uint8 trigger = 8b11111111;
  
  sdram_clock   := clock;
  sdram_reset   := reset;
  
$$if HAS_COMPUTE_CLOCK then
  compute_clock := ~counter[0,1]; // x2 slower
  compute_reset := (trigger > 0);
$$end

  video_clock   := counter[1,1]; // x4 slower
  video_reset   := (trigger > 0);
  
  while (1) {	  
    counter = counter + 1;
	  trigger = trigger >> 1;
  }
}
$$end

// ------------------------- 

$$if DE10NANO then
import('de10nano_clk_50_25_100_100ph180.v')
import('de10nano_clk_100_25_100ph180.v')
$$if HDMI then
$$error('HDMI not yet implemented')
$$end
// reset
import('reset_conditioner.v')
$$end

$$if ULX3S then
// Clock
import('ulx3s_clk_50_25_100_100ph180.v')
// reset
import('reset_conditioner.v')
$$end

// ------------------------- 

// SDRAM controller
$include('sdramctrl.ice')

// ------------------------- 

// video sdram framework
$include('video_sdram.ice')

// ------------------------- 

algorithm main(
  output uint8 leds,
$$if not ICARUS then
  // SDRAM
  output uint1  sdram_cle,
  output uint2  sdram_dqm,
  output uint1  sdram_cs,
  output uint1  sdram_we,
  output uint1  sdram_cas,
  output uint1  sdram_ras,
  output uint2  sdram_ba,
  output uint13 sdram_a,
$$if VERILATOR then
  output uint1  sdram_clock, // sdram controller clock
  input  uint16 sdram_dq_i,
  output uint16 sdram_dq_o,
  output uint1  sdram_dq_en,
$$else
  output uint1  sdram_clk,  // sdram chip clock != internal sdram_clock
  inout  uint16 sdram_dq,
$$end
$$end
$$if ICARUS or VERILATOR then
  output uint1 video_clock,
$$end
$$if DE10NANO then
  output uint4 kpadC,
  input  uint4 kpadR,
$$end
$$if ULX3S then
  input  uint7 btns,
$$end
$$if VGA then  
  // VGA
  output uint$color_depth$ video_r,
  output uint$color_depth$ video_g,
  output uint$color_depth$ video_b,
  output uint1 video_hs,
  output uint1 video_vs,
$$end
$$if HDMI then
$$if ULX3S then
  output uint3 gpdi_dp,
  output uint3 gpdi_dn,
$$else
$$  error('no HDMI support')
$$end
$$end  
) <@sdram_clock,!sdram_reset> {

uint1 video_reset   = 0;
uint1 sdram_reset   = 0;

$$if ICARUS or VERILATOR then
// --- PLL
uint1 compute_reset = 0;
uint1 compute_clock = 0;
$$if ICARUS then
uint1 sdram_clock   = 0;
$$end
pll clockgen<@clock,!reset>(
  video_clock   :> video_clock,
  video_reset   :> video_reset,
  sdram_clock   :> sdram_clock,
  sdram_reset   :> sdram_reset,
$$if HAS_COMPUTE_CLOCK then
  compute_clock :> compute_clock,
  compute_reset :> compute_reset
$$end
);
$$elseif DE10NANO then
  // --- clock
  uint1 video_clock  = 0;
  uint1 sdram_clock  = 0;
  uint1 pll_lock     = 0;
  uint1 not_pll_lock = 0;
  $$if HAS_COMPUTE_CLOCK then
    uint1 compute_clock = 0;
    uint1 compute_reset = 0;
    de10nano_clk_50_25_100_100ph180 clk_gen(
      refclk    <: clock,
      rst       <: not_pll_lock,
      outclk_0  :> compute_clock,
      outclk_1  :> video_clock,
      outclk_2  :> sdram_clock, // controller
      outclk_3  :> sdram_clk,   // chip
      locked    :> pll_lock
    );
  $$else
    de10nano_clk_100_25_100ph180 clk_gen(
      refclk    <: clock,
      rst       <: not_pll_lock,
      outclk_0  :> sdram_clock, // controller
      outclk_1  :> video_clock,
      outclk_2  :> sdram_clk,   // chip
      locked    :> pll_lock
    );
  $$end
  // --- video clean reset
  reset_conditioner video_rstcond (
    rcclk <: video_clock,
    in    <: reset,
    out   :> video_reset
  );  
  // --- SDRAM clean reset
  reset_conditioner sdram_rstcond (
    rcclk <: sdram_clock,
    in    <: reset,
    out   :> sdram_reset
  );
  $$if HAS_COMPUTE_CLOCK then
  // --- compute clean reset
  reset_conditioner compute_rstcond (
    rcclk <: compute_clock,
    in    <: reset,
    out   :> compute_reset
  );
  $$end
$$elseif ULX3S then
$$HAS_COMPUTE_CLOCK = true
  // --- clock
  uint1 video_clock   = 0;
  uint1 sdram_clock   = 0;
  uint1 pll_lock      = 0;
  uint1 compute_clock = 0;
  uint1 compute_reset = 0;
  $$print('ULX3S at 50 MHz compute clock, 100 MHz SDRAM')
  ulx3s_clk_50_25_100_100ph180 clk_gen(
    clkin    <: clock,
    clkout0  :> compute_clock,
    clkout1  :> video_clock,
    clkout2  :> sdram_clock, // controller
    clkout3  :> sdram_clk,   // chip
    locked   :> pll_lock
  ); 
  // --- video clean reset
  reset_conditioner video_rstcond (
    rcclk <: video_clock,
    in    <: reset,
    out   :> video_reset
  );  
  // --- SDRAM clean reset
  reset_conditioner sdram_rstcond (
    rcclk <: sdram_clock,
    in    <: reset,
    out   :> sdram_reset
  );
  // --- compute clean reset
  reset_conditioner compute_rstcond (
    rcclk <: compute_clock,
    in    <: reset,
    out   :> compute_reset
  );
$$end

uint1  video_active = 0;
uint1  video_vblank = 0;
uint11 video_x  = 0;
uint10 video_y  = 0;

$$if VGA then
// --- VGA
vga vga_driver<@video_clock,!video_reset>(
  vga_hs :> video_hs,
	vga_vs :> video_vs,
	vga_x  :> video_x,
	vga_y  :> video_y,
	vblank :> video_vblank,
	active :> video_active,
);
$$end

$$if HDMI then
// --- HDMI
uint6 video_r = 0;
uint6 video_g = 0;
uint6 video_b = 0;

uint8 vr := video_r<<2;
uint8 vg := video_g<<2;
uint8 vb := video_b<<2;

hdmi hdmi_driver<@clock,!reset>( // NOTE: should be @video_clock,!video_reset, but ...
                                 // does not work for some reason on ULX3S
//hdmi hdmi_driver<@video_clock,!video_reset>(                                 
  x       :> video_x,
  y       :> video_y,
  vblank  :> video_vblank,
  active  :> video_active,
  red     <: vr,
  green   <: vg,
  blue    <: vb,
  gpdi_dp :> gpdi_dp,
  gpdi_dn :> gpdi_dn,
);
$$end

// --- SDRAM
$$if ICARUS then
uint1  sdram_cle   = 0;
uint2  sdram_dqm   = 0;
uint1  sdram_cs    = 0;
uint1  sdram_we    = 0;
uint1  sdram_cas   = 0;
uint1  sdram_ras   = 0;
uint2  sdram_ba    = 0;
uint13 sdram_a     = 0;
uint16 sdram_dq    = 0;

simul_sdram simul(
  sdram_clk <: clock,
  <:auto:>
);
$$end

sdchipio sdchip;
sdio     sd;

sdramctrl_chip memory_chip(
  sd         <:> sdchip,
$$if VERILATOR then
  dq_i       <: sdram_dq_i,
  dq_o       :> sdram_dq_o,
  dq_en      :> sdram_dq_en,
$$end
  <:auto:>
);

sdramctrl memory(
  sdchip <:> sdchip,
  sd     <:> sd,
);

// --- SDRAM switcher

sdio sd0;
sdio sd1;

sdram_switcher sd_switcher(
  sd         <:>  sd,
  sd0        <:>  sd0,
  sd1        <:>  sd1,
);

// --- Frame buffer row memory
// dual clock crosses from sdram to vga

  dualport_bram uint8 fbr0<@video_clock,@sdram_clock>[320] = {};
  dualport_bram uint8 fbr1<@video_clock,@sdram_clock>[320] = {};
  
// --- Display
  uint1 row_busy = 0;
  frame_display display<@video_clock,!video_reset>(
    pixaddr0   :> fbr0.addr0,
    pixdata0_r <: fbr0.rdata0,
    pixaddr1   :> fbr1.addr0,
    pixdata1_r <: fbr1.rdata0,
    row_busy   :> row_busy,
	  video_x    <: video_x,
	  video_y    <: video_y,
    video_r    :> video_r,
    video_g    :> video_g,
    video_b    :> video_b,
    <:auto:>
  );

  uint1 onscreen_fbuffer = 0;
  
  // --- Frame buffer row updater
  frame_buffer_row_updater fbrupd(
    pixaddr0   :> fbr0.addr1,
    pixdata0_w :> fbr0.wdata1,
    pixwenable0:> fbr0.wenable1,
    pixaddr1   :> fbr1.addr1,
    pixdata1_w :> fbr1.wdata1,
    pixwenable1:> fbr1.wenable1,
    row_busy   <: row_busy,
    vsync      <: video_vblank,
    sd         <:> sd0,
    fbuffer    <: onscreen_fbuffer
  );

  // --- Frame drawer
  frame_drawer drawer
$$if HAS_COMPUTE_CLOCK then
    <@compute_clock,!compute_reset>
$$else
    <@sdram_clock,!sdram_reset>
$$end
(
    vsync       <:  video_vblank,
    sd          <:> sd1,
    fbuffer     :>  onscreen_fbuffer,
$$if HAS_COMPUTE_CLOCK then  
    sdram_clock <:  sdram_clock,
    sdram_reset <:  sdram_reset,
$$end
    <:auto:>
  );

  uint8 frame       = 0;

$$if DE10NANO then
  not_pll_lock := ~pll_lock;
$$end

  // ---------- let's go

  // start the switcher
  sd_switcher <- ();
  
  // start the frame drawer
$$if not HAS_COMPUTE_CLOCK then
  drawer <- ();
$$end
 
  // start the frame buffer row updater
  fbrupd <- ();
 
  // we count a number of frames and stop
$$if HARDWARE then
  while (1) { 
    frame = frame + 1;
  }
$$else
  while (frame < 64) {

    while (video_vblank == 1) { }
	  //__display("vblank off");

	  while (video_vblank == 0) { }
    //__display("vblank on");

    frame = frame + 1;
    
  }
$$end

}

// ------------------------- 
