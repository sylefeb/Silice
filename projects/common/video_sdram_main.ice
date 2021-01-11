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

$$if HARDWARE then
// Reset
$include('clean_reset.ice')
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
  output  uint1 compute_clock,
  output  uint1 compute_reset
) <autorun> {
  uint3 counter = 0;
  uint8 trigger = 8b11111111;
  
  sdram_clock   := clock;
  sdram_reset   := (trigger > 0);
  
  compute_clock := ~counter[0,1]; // x2 slower
  compute_reset := (trigger > 0);

  video_clock   := counter[1,1]; // x4 slower
  video_reset   := (trigger > 0);
  
  while (1) {	  
    counter = counter + 1;
	  trigger = trigger >> 1;
  }
}
$$end

// ------------------------- 

// TODO add back Mojov3

$$if DE10NANO then
$$if VGA then
import('de10nano_clk_50_25_100_100ph180.v')
$$else
// TODO: hdmi
$$end
$$end

$$if ULX3S then
// Clock
import('ulx3s_clk_50_25_100_100ph180.v')
$$end

$$if SDCARD then
$include('sdcard.ice')
$include('sdcard_streamer.ice')
$$end

// ------------------------- 

// SDRAM controller
$$read_burst_length = 8 -- NOTE: mandatory for the framebuffer!
$include('sdram_interfaces.ice')
$include('sdram_controller_autoprecharge_r128_w8.ice')
// include('sdram_controller_r128_w8.ice')
$include('sdram_arbitrers.ice')
$include('sdram_utils.ice')

// ------------------------- 

// video sdram framework
$include('video_sdram.ice')

// ------------------------- 

$$if init_data_bytes then

$$if SDCARD then

$$print('setting up for SDRAM initialization from SDCARD')

algorithm init_data(
  output  uint1 sd_clk,
  output  uint1 sd_mosi,
  output  uint1 sd_csn,
  input   uint1 sd_miso,
  output  uint8 leds,
  output  uint1 ready = 0,
  sdram_user sd
) <autorun> {

  streamio stream;
  sdcard_streamer streamer(
    sd_clk  :> sd_clk,
    sd_mosi :> sd_mosi,
    sd_csn  :> sd_csn,
    sd_miso <: sd_miso,
    stream  <:> stream
  );

  // maintain low (pulses high when needed)
  stream.next   := 0;
  sd.in_valid   := 0;
  // only writes to memory
  sd.rw         := 1;

  leds = 1;

  // wait for sdcard controller to be ready  
  while (stream.ready == 0)    { }

  leds = 2;

  // read some
  {
    uint23 to_read = 0;
    while (to_read < $init_data_bytes$) {
      stream.next  = 1;
      while (stream.ready == 0) { }
      leds            = to_read[14,8];

      // write to sdram
      sd.data_in      = stream.data;
      sd.addr         = {1b1,1b0,24b0} | to_read;
      sd.in_valid     = 1; // go ahead!      
      // -> wait for sdram to be done
      while (!sd.done) { }     

      // next
      to_read = to_read + 1;
    }
  }

  leds  = 8b10000000;

  ready = 1;
}

$$elseif SIMULATION and data_hex then

// for simulation

algorithm init_data(
  sdram_user sd,
  output  uint1 ready = 0
) <autorun> {

  brom uint8 sdcard_data[] = {
$data_hex$
  };

  uint22 to_read = 0;
  uint8  data    = 0;

  sd.in_valid := 0;
  sd.rw       := 1;
  __display("loading %d bytes from sdcard (simulation)",$init_data_bytes$);
  while (to_read < $init_data_bytes$) {
    sdcard_data.addr = to_read;
++:    
    data            = sdcard_data.rdata;

    // write to sdram
    sd.data_in      = data;
    sd.addr         = {1b1,1b0,24b0} | to_read;
    sd.in_valid     = 1; // go ahead!
    // wait for sdram to be done
    while (!sd.done) { }

    // next
    to_read = to_read + 1;
  }
  __display("loading %d bytes from sdcard ===> done",$init_data_bytes$);

  ready = 1;  
}

$$end
$$end

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
$$if ULX3S or DE10NANO then
  input  uint7 btns,
$$end
$$if SDCARD then
  // sdcard
  output! uint1 sd_clk,
  output! uint1 sd_mosi,
  output! uint1 sd_csn,
  input   uint1 sd_miso,  
$$end  
$$if VGA then  
  // VGA
  output uint$color_depth$ video_r,
  output uint$color_depth$ video_g,
  output uint$color_depth$ video_b,
  output uint1 video_hs,
  output uint1 video_vs,
$$end
$$if AUDIO then
  output uint4 audio_l,
  output uint4 audio_r,
$$end
$$if HDMI then
$$if ULX3S then
  output uint4 gpdi_dp,
//  output uint4 gpdi_dn,
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
    compute_clock :> compute_clock,
    compute_reset :> compute_reset
  );
$$elseif DE10NANO then
  // --- clock
  uint1 video_clock  = 0;
  uint1 sdram_clock  = 0;
  uint1 pll_lock     = 0;
  uint1 not_pll_lock = 0;
  uint1 compute_clock = 0;
  uint1 compute_reset = 0;
  $$print('DE10NANO at 50 MHz compute clock, 100 MHz SDRAM')
  de10nano_clk_50_25_100_100ph180 clk_gen(
    refclk    <: clock,
    rst       <: not_pll_lock,
    outclk_0  :> compute_clock,
    outclk_1  :> video_clock,
    outclk_2  :> sdram_clock, // controller
    outclk_3  :> sdram_clk,   // chip
    locked    :> pll_lock
  );
  // --- video clean reset
  clean_reset video_rstcond<@video_clock,!reset> (
    out   :> video_reset
  );  
  // --- SDRAM clean reset
  clean_reset sdram_rstcond<@sdram_clock,!reset> (
    out   :> sdram_reset
  );
  // --- compute clean reset
  clean_reset compute_rstcond<@compute_clock,!reset> (
    out   :> compute_reset
  );
$$elseif ULX3S then
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
  clean_reset video_rstcond<@video_clock,!reset> (
    out   :> video_reset
  );  
  // --- SDRAM clean reset
  clean_reset sdram_rstcond<@sdram_clock,!reset> (
    out   :> sdram_reset
  );
  // --- compute clean reset
  clean_reset compute_rstcond<@compute_clock,!reset> (
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
  uint8 video_r = 0;
  uint8 video_g = 0;
  uint8 video_b = 0;

  hdmi hdmi_driver<@video_clock,!video_reset>(
    x       :> video_x,
    y       :> video_y,
    vblank  :> video_vblank,
    active  :> video_active,
    red     <: video_r,
    green   <: video_g,
    blue    <: video_b,
    gpdi_dp :> gpdi_dp,
//    gpdi_dn :> gpdi_dn,
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

  simul_sdram simul<@sdram_clock,!sdram_reset>(
    sdram_clk <: clock,
    <:auto:>
  );
$$end

  // --- SDRAM raw interface

  sdram_r128w8_io sdm;
  
  sdram_controller_autoprecharge_r128_w8 memory<@sdram_clock,!sdram_reset>(
  // sdram_controller_r128_w8 memory<@sdram_clock,!sdram_reset>(
    sd         <:> sdm,
  $$if VERILATOR then
    dq_i       <: sdram_dq_i,
    dq_o       :> sdram_dq_o,
    dq_en      :> sdram_dq_en,
  $$end
    <:auto:>
  );

  // --- SDRAM byte memory interface

  sdram_r128w8_io sdf; // framebuffer
  sdram_r128w8_io sdd; // drawer
  sdram_r128w8_io sdi; // init

  // --- SDRAM arbitrer, framebuffer (0) / drawer (1) / init (2)
  
  sdram_arbitrer_3way sd_switcher<@sdram_clock,!sdram_reset>(
    sd         <:>  sdm,
    sd0        <:>  sdf,
    sd1        <:>  sdd,
    sd2        <:>  sdi,
  );

  // --- Frame buffer row memory
  // dual clock crosses from sdram to vga
  simple_dualport_bram uint128 fbr0<@video_clock,@sdram_clock>[$320//16$] = uninitialized;
  simple_dualport_bram uint128 fbr1<@video_clock,@sdram_clock>[$320//16$] = uninitialized;

  // --- Palette
  simple_dualport_bram uint24 palette[] = {
    // palette from pre-processor table
$$  for i=0,255 do
$$if palette then    
  $palette[1+i]$,
$$else  
  $(i) | (((i<<1)&255)<<8) | (((i<<2)&255)<<16)$,
$$  end
$$end
  };  
  
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
    palette   <:> palette,
    <:auto:>
  );

  uint1 onscreen_fbuffer = 0;
  
  // --- Frame buffer row updater
  frame_buffer_row_updater fbrupd<@sdram_clock,!sdram_reset>(
    pixaddr0   :> fbr0.addr1,
    pixdata0_w :> fbr0.wdata1,
    pixwenable0:> fbr0.wenable1,
    pixaddr1   :> fbr1.addr1,
    pixdata1_w :> fbr1.wdata1,
    pixwenable1:> fbr1.wenable1,
    row_busy   <: row_busy,
    vsync      <: video_vblank,
    sd         <:> sdf,
    fbuffer    <: onscreen_fbuffer
  );

  // --- Init from SDCARD
  sdram_r128w8_io sdh;
  
  sdram_half_speed_access sdaccess<@sdram_clock,!sdram_reset>(
    sd      <:> sdi,
    sdh     <:> sdh,
  );

  uint1 data_ready = 0;
$$if (SDCARD and init_data_bytes) or (SIMULATION and init_data_bytes) then
  init_data init<@compute_clock,!compute_reset>(
    sd    <:> sdh,
    ready  :> data_ready,
    <:auto:>
  );

  uint1 frame_drawer_reset ::= compute_reset || (~data_ready);
$$else
  uint1 frame_drawer_reset ::= compute_reset;
$$end

  // --- Frame drawer
$$if frame_drawer_at_sdram_speed then
  frame_drawer drawer<@sdram_clock,!sdram_reset>(
$$else  
  frame_drawer drawer<@compute_clock,!frame_drawer_reset>(
$$end  
    vsync       <:  video_vblank,
    sd          <:> sdd,
    fbuffer     :>  onscreen_fbuffer,
    sdram_clock <:  sdram_clock,
    sdram_reset <:  sdram_reset,
    <:auto:>
  );

  uint8 frame       = 0;

  // ---------- let's go (all modules autorun)
 
$$if HARDWARE then
  while (1) { }
$$else
  // we count a number of frames and stop
$$if ICARUS then
  while (frame < 4) {
$$else
$$if verbose then
  while (frame < 1) {
$$else
  while (frame < 10) {
$$end  
$$end    
    while (video_vblank == 1) { }
	  while (video_vblank == 0) { }
    frame = frame + 1;    
  }
$$end

}

// ------------------------- 
