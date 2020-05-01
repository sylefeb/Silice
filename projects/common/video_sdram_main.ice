// SL 2019-10

$$if ICARUS then
  // SDRAM simulator
  append('mt48lc32m8a2.v')
  import('simul_sdram.v')
$$end

$$USE_ICE_SDRAM_CTRL = _true

$$if USE_ICE_SDRAM_CTRL then
$include('sdramctrl.ice')
$$else
append('sdram_clock.v')
import('sdram.v')
$$end

// Frame buffer row
import('dual_frame_buffer_row.v')

$$if VGA then
// VGA driver
$include('vga.ice')
$$end

$$if HDMI then
// HDMI driver
append('verilog/serdes_n_to_1.v')
append('verilog/simple_dual_ram.v')
append('verilog/tmds_encoder.v')
append('verilog/async_fifo.v')
append('verilog/fifo_2x_reducer.v')
append('verilog/dvi_encoder.v')
import('verilog/hdmi_encoder.v')
$$end

$include('video_sdram.ice')

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
  output! uint1 sdram_reset
) <autorun>
{
  uint3 counter = 0;
  uint8 trigger = 8b11111111;
  
  sdram_clock   := clock;
  sdram_reset   := reset;
  
  video_clock     := counter[1,1];
  video_reset     := (trigger > 0);
  
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
$$elseif MOJO then
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

uint1 video_reset = 0;
uint1 sdram_reset = 0;

$$if ICARUS or VERILATOR then

// --- PLL

$$if ICARUS then
  uint1 sdram_clock = 0;
$$end

pll clockgen<@clock,!reset>(
  video_clock :> video_clock,
  video_reset :> video_reset,
  sdram_clock :> sdram_clock,
  sdram_reset :> sdram_reset
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

uint23 saddr       = 0;
uint2  swbyte_addr = 0;
uint1  srw         = 0;
uint32 sdata_in    = 0;
uint32 sdata_out   = 0;
uint1  sbusy       = 0;
uint1  sin_valid   = 0;
uint1  sout_valid  = 0;

$$if USE_ICE_SDRAM_CTRL then
sdramctrl memory(
$$else
sdram memory(
$$end
  clk        <: sdram_clock,
  rst        <: sdram_reset,
  addr       <: saddr,
  wbyte_addr <: swbyte_addr,
  rw         <: srw,
  data_in    <: sdata_in,
  data_out   :> sdata_out,
  busy       :> sbusy,
  in_valid   <: sin_valid,
  out_valid  :> sout_valid,
$$if VERILATOR and USE_ICE_SDRAM_CTRL then
  dq_i      <: sdram_dq_i,
  dq_o      :> sdram_dq_o,
  dq_en     :> sdram_dq_en,
$$end
  <:auto:>
);

// --- SDRAM switcher

uint23 saddr0       = 0;
uint2  swbyte_addr0 = 0;
uint1  srw0         = 0;
uint32 sd_in0       = 0;
uint32 sd_out0      = 0;
uint1  sbusy0       = 0;
uint1  sin_valid0   = 0;
uint1  sout_valid0  = 0;

uint23 saddr1       = 0;
uint2  swbyte_addr1 = 0;
uint1  srw1         = 0;
uint32 sd_in1       = 0;
uint32 sd_out1      = 0;
uint1  sbusy1       = 0;
uint1  sin_valid1   = 0;
uint1  sout_valid1  = 0;

uint1  select       = 0;

sdram_switcher sd_switcher<@sdram_clock,!sdram_reset>(
  select       <: select,

  saddr        :> saddr,
  swbyte_addr  :> swbyte_addr,
  srw          :> srw,
  sd_in        :> sdata_in,
  sd_out       <: sdata_out,
  sbusy        <: sbusy,
  sin_valid    :> sin_valid,
  sout_valid   <: sout_valid,

  saddr0       <: saddr0,
  swbyte_addr0 <: swbyte_addr0,
  srw0         <: srw0,
  sd_in0       <: sd_in0,
  sd_out0      :> sd_out0,
  sbusy0       :> sbusy0,
  sin_valid0   <: sin_valid0,
  sout_valid0  :> sout_valid0,

  saddr1       <: saddr1,
  swbyte_addr1 <: swbyte_addr1,
  srw1         <: srw1,
  sd_in1       <: sd_in1,
  sd_out1      :> sd_out1,
  sbusy1       :> sbusy1,
  sin_valid1   <: sin_valid1,
  sout_valid1  :> sout_valid1
);

// --- Frame buffer row memory
// dual clock crosses from sdram to vga

  uint16 pixaddr_r = 0;
  uint16 pixaddr_w = 0;
  uint32 pixdata_r = 0;
  uint32 pixdata_w = 0;
  uint1  pixwenable  = 0;

  dual_frame_buffer_row fbr(
    rclk    <: video_clock,
    wclk    <: sdram_clock,
    raddr   <: pixaddr_r,
    rdata   :> pixdata_r,
    waddr   <: pixaddr_w,
    wdata   <: pixdata_w,
    wenable <: pixwenable
  );

// --- Display

  uint1 row_busy = 0;

  frame_display display<@video_clock,!video_reset>(
    pixaddr   :> pixaddr_r,
    pixdata_r <: pixdata_r,
    row_busy  :> row_busy,
	  video_x   <: video_x,
	  video_y   <: video_y,
    video_r   :> video_r,
    video_g   :> video_g,
    video_b   :> video_b,
    <:auto:>
  );

  uint1 onscreen_fbuffer = 0;
  
// --- Frame buffer row updater
  frame_buffer_row_updater fbrupd<@sdram_clock,!sdram_reset>(
    working    :> select,
    pixaddr    :> pixaddr_w,
    pixdata_w  :> pixdata_w,
    pixwenable :> pixwenable,
    row_busy   <: row_busy,
    vsync      <: video_vblank,
    saddr      :> saddr0,
    srw        :> srw0,
    sdata_in   :> sd_in0,
    sdata_out  <: sd_out0,
    sbusy      <: sbusy0,
    sin_valid  :> sin_valid0,
    sout_valid <: sout_valid0,
    fbuffer    <: onscreen_fbuffer
  );
 
// --- Frame drawer
  frame_drawer drawer<@sdram_clock,!sdram_reset>(
    vsync      <: video_vblank,
    saddr      :> saddr1,
    swbyte_addr:> swbyte_addr1,
    srw        :> srw1,
    sdata_in   :> sd_in1,
    sdata_out  <: sd_out1,
    sbusy      <: sbusy1,
    sin_valid  :> sin_valid1,
    sout_valid <: sout_valid1,
    fbuffer    :> onscreen_fbuffer
  );

  uint8 frame       = 0;

$$if MOJO then
  uint1 lastfbuffer = 1;
  uint6 counter     = 0;
$$end

  // ---------- let's go

  // start the switcher
  sd_switcher <- ();
  
  // start the frame drawer
  drawer <- ();
   
  // start the frame buffer row updater
  fbrupd <- ();
 
  // we count a number of frames and stop
$$if MOJO then
  while (1) { 
  
    // wait while vga draws  
	  while (video_vblank == 0) { }

    // one more vga frame
    if (counter < 63) {
      counter = counter + 1;
    }

++: // wait for drawer to swap
    if (onscreen_fbuffer != lastfbuffer) {
      // one more drawer frame
      lastfbuffer = onscreen_fbuffer;
      led         = counter;
      counter     = 0;
    }

    // wait for next frame to start
	  while (video_vblank == 1) { }
    
  }
$$else
  while (frame < 128) {

    while (video_vblank == 1) { }
	  //__display("vblank off");

	  while (video_vblank == 0) { }
    //__display("vblank on");

    frame = frame + 1;
    
  }
$$end

}

// ------------------------- 
