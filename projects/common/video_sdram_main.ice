// SL 2019-10

$$USE_ICE_SDRAM_CTRL = true

$$if ICARUS then
  // SDRAM simulator
  append('mt48lc32m8a2.v')
  import('simul_sdram.v')
$$end

$$if VGA then
// VGA driver
$include('vga.ice')
$$end

$$if HDMI then
// HDMI driver
append('serdes_n_to_1.v')
append('simple_dual_ram.v')
append('tmds_encoder.v')
append('async_fifo.v')
append('fifo_2x_reducer.v')
append('dvi_encoder.v')
import('hdmi_encoder.v')
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
  output! uint1 video_clock,
  output! uint1 video_reset,
  output! uint1 sdram_clock,
  output! uint1 sdram_reset,
$$if HAS_COMPUTE_CLOCK then
  output! uint1 compute_clock,
  output! uint1 compute_reset
$$end
) <autorun>
{
  uint3 counter = 0;
  uint8 trigger = 8b11111111;
  
  sdram_clock   := clock;
  sdram_reset   := reset;
  
$$if HAS_COMPUTE_CLOCK then
  compute_clock := counter[0,1]; // x2 slower
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

$$if MOJO then
// clock
$$if VGA then
import('mojo_clk_100_25.v')
$$else
import('mojo_clk_100_75.v')
$$end
// reset
import('reset_conditioner.v')
$$end

$$if DE10NANO then
$$if VGA then
import('de10nano_clk_100_25.v')
$$else
// TODO: hdmi
$$end
// reset
import('reset_conditioner.v')
$$end

$$if ULX3S then
// Clock
import('ulx3s_clk_50_25_100.v')
import('ulx3s_clk_50_25_50.v')
import('ulx3s_clk_50_25_75.v')
import('ulx3s_clk_25_25_100.v')
import('ulx3s_clk_25_25_50.v')
import('ulx3s_clk_100_25.v')
import('ulx3s_clk_25_25.v')
// reset
import('reset_conditioner.v')
$$end

// ------------------------- 

// SDRAM controller
$$if USE_ICE_SDRAM_CTRL then
$include('sdramctrl.ice')
$$else
append('sdram_clock.v')
import('sdram.v')
$$end

// ------------------------- 

// video sdram framework
$include('video_sdram.ice')

// ------------------------- 

algorithm main(
$$if not ICARUS then
  // SDRAM
  output! uint1  sdram_cle,
  output! uint1  sdram_dqm,
  output! uint1  sdram_cs,
  output! uint1  sdram_we,
  output! uint1  sdram_cas,
  output! uint1  sdram_ras,
  output! uint2  sdram_ba,
  output! uint13 sdram_a,
$$if VERILATOR then
  output! uint1  sdram_clock,
  input   uint8  sdram_dq_i,
  output! uint8  sdram_dq_o,
  output! uint1  sdram_dq_en,
$$else
  output! uint1  sdram_clk, // sdram chip clock != internal sdram_clock
  inout   uint8  sdram_dq,
$$end
$$end
$$if MOJO then
  output! uint6  led,
  output! uint1  spi_miso,
  input   uint1  spi_ss,
  input   uint1  spi_mosi,
  input   uint1  spi_sck,
  output! uint4  spi_channel,
  input   uint1  avr_tx,
  output! uint1  avr_rx,
  input   uint1  avr_rx_busy,
$$end
$$if ICARUS or VERILATOR then
  output! uint1 video_clock,
$$end
$$if DE10NANO then
  output! uint8 led,
  output! uint4 kpadC,
  input   uint4 kpadR,
  output! uint1 lcd_rs,
  output! uint1 lcd_rw,
  output! uint1 lcd_e,
  output! uint8 lcd_d,
  output! uint1 oled_din,
  output! uint1 oled_clk,
  output! uint1 oled_cs,
  output! uint1 oled_dc,
  output! uint1 oled_rst,  
$$end
$$if ULX3S then
  output! uint8 led,
  input   uint7 btn,
$$end
$$if VGA then  
  // VGA
  output! uint$color_depth$ video_r,
  output! uint$color_depth$ video_g,
  output! uint$color_depth$ video_b,
  output! uint1 video_hs,
  output! uint1 video_vs
$$end
$$if HDMI then  
  // HDMI
  output! uint4 hdmi1_tmds,
  output! uint4 hdmi1_tmdsb
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
$$elseif MOJO then
  uint1 video_clock   = 0;
$$if VGA then
  // --- clock
  clk_100_25 clk_gen (
    CLK_IN1  <: clock,
    CLK_OUT1 :> sdram_clock,
    CLK_OUT2 :> video_clock
  );
$$end
$$if HDMI then
  // --- clock
  uint1 hdmi_clock   = 0;
  clk_100_75 clk_gen (
    CLK_IN1  <: clock,
    CLK_OUT1 :> sdram_clock,
    CLK_OUT2 :> hdmi_clock
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
    in  <: reset,
    out :> sdram_reset
  );
$$elseif DE10NANO then
  // --- clock
  uint1 video_clock  = 0;
  uint1 sdram_clock  = 0;
  uint1 pll_lock     = 0;
  uint1 not_pll_lock = 0;
  de10nano_clk_100_25 clk_gen(
    refclk    <: clock,
    rst       <: not_pll_lock,
    outclk_0  :> sdram_clock,
    outclk_1  :> video_clock,
    locked    :> pll_lock
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
    in  <: reset,
    out :> sdram_reset
  );
$$elseif ULX3S then
  // --- clock
  uint1 video_clock   = 0;
  uint1 sdram_clock   = 0;
  uint1 pll_lock      = 0;
$$if HAS_COMPUTE_CLOCK then
  uint1 compute_clock = 0;
  uint1 compute_reset = 0;
$$if ULX3S_25MHZ then
$$print('using ULX3S at 25 MHz, compute clock')
  ulx3s_clk_25_25_50 clk_gen(
    clkin    <: clock,
    clkout0  :> compute_clock,
    clkout1  :> video_clock,
    clkout2  :> sdram_clock,
    locked   :> pll_lock
  ); 
$$else
$$if ULX3S then
  ulx3s_clk_50_25_75 clk_gen(
    clkin    <: clock,
    clkout0  :> compute_clock,
    clkout1  :> video_clock,
    clkout2  :> sdram_clock,
    locked   :> pll_lock
  ); 
$$else
  ulx3s_clk_50_25_100 clk_gen(
    clkin    <: clock,
    clkout0  :> compute_clock,
    clkout1  :> video_clock,
    clkout2  :> sdram_clock,
    locked   :> pll_lock
  ); 
$$end
$$end
$$else
$$if ULX3S_25MHZ then
$$print('using ULX3S at 25 MHz')
  ulx3s_clk_25_25 clk_gen(
    clkin    <: clock,
    clkout0  :> sdram_clock,
    clkout1  :> video_clock,
    locked   :> pll_lock
  ); 
$$else
  ulx3s_clk_100_25 clk_gen(
    clkin    <: clock,
    clkout0  :> sdram_clock,
    clkout1  :> video_clock,
    locked   :> pll_lock
  ); 
$$end
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
	active :> video_active,
	vblank :> video_vblank,
	vga_x  :> video_x,
	vga_y  :> video_y
);
$$end

$$if HDMI then
// --- HDMI
uint8 video_r = 0;
uint8 video_g = 0;
uint8 video_b = 0;
hdmi_encoder hdmi(
  clk    <: hdmi_clock,
  rst    <: video_reset,
  red    <: video_r,
  green  <: video_g,
  blue   <: video_b,
  pclk   :> video_clock,
  tmds   :> hdmi1_tmds,
  tmdsb  :> hdmi1_tmdsb,
  vblank :> video_vblank,
  active :> video_active,
  x      :> video_x,
  y      :> video_y
);
$$end

// --- SDRAM

$$if ICARUS then
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
$$end

sdio sd;

$$if USE_ICE_SDRAM_CTRL then
sdramctrl memory(
$$else
sdram memory(
$$end
  clk        <:  sdram_clock,
  rst        <:  sdram_reset,
  sd         <:> sd,
$$if VERILATOR and USE_ICE_SDRAM_CTRL then
  dq_i       <: sdram_dq_i,
  dq_o       :> sdram_dq_o,
  dq_en      :> sdram_dq_en,
$$end
  <:auto:>
);

// --- SDRAM switcher

sdio sd0;
sdio sd1;

uint1  select       = 0;

sdram_switcher sd_switcher<@sdram_clock,!sdram_reset>(
  select     <:  select,
  sd         <:> sd,
  sd0        <:> sd0,
  sd1        <:> sd1,
);

// --- Frame buffer row memory
// dual clock crosses from sdram to vga

  dualport_bram uint32 fbr0<@video_clock,@sdram_clock>[80] = {};
  dualport_bram uint32 fbr1<@video_clock,@sdram_clock>[80] = {};
  
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
  frame_buffer_row_updater fbrupd<@sdram_clock,!sdram_reset>(
    working    :> select,
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
  
    // wait while vga draws  
	  while (video_vblank == 0) { }

    // wait for next frame to start
	  while (video_vblank == 1) { }
    
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
