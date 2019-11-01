// SL 2019-10

// SDRAM controller
import('sdram_mojo.v')

// Frame buffer row
import('dual_frame_buffer_row.v')

// VGA driver
$include('vga.ice')
$include('vga_sdram.ice')

// Clock
import('mojo_clk_100_25.v')
// Reset
import('reset_conditioner.v')

// ------------------------- 

algorithm main(
  output! uint8  led,
  output! uint1  spi_miso,
  input   uint1  spi_ss,
  input   uint1  spi_mosi,
  input   uint1  spi_sck,
  output! uint4  spi_channel,
  input   uint1  avr_tx,
  output! uint1  avr_rx,
  input   uint1  avr_rx_busy,
  // SDRAM
  output! uint1  sdram_clk,
  output! uint1  sdram_cle,
  output! uint1  sdram_dqm,
  output! uint1  sdram_cs,
  output! uint1  sdram_we,
  output! uint1  sdram_cas,
  output! uint1  sdram_ras,
  output! uint2  sdram_ba,
  output! uint13 sdram_a,
  inout   uint8  sdram_dq,
  // VGA
  output! uint1  vga_r,
  output! uint1  vga_g,
  output! uint1  vga_b,
  output! uint1  vga_hs,
  output! uint1  vga_vs
) <@sdram_clock,!sdram_reset> {

  uint1 vga_clock   = 0;
  uint1 vga_reset   = 0;
  uint1 sdram_reset = 0;
  uint1 sdram_clock = 0;

  // --- clock

  clk_100_25 clk_gen (
    CLK_IN1  <: clock,
    CLK_OUT1 :> sdram_clock,
    CLK_OUT2 :> vga_clock
  );

  // --- clean reset

  reset_conditioner vga_rstcond (
    rcclk <: vga_clock,
    in  <: reset,
    out :> vga_reset
  );

  reset_conditioner sdram_rstcond (
    rcclk <: sdram_clock,
    in  <: reset,
    out :> sdram_reset
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
uint2  swbyte_addr = 0;
uint1  srw         = 0;
uint32 sdata_in    = 0;
uint32 sdata_out   = 0;
uint1  sbusy       = 0;
uint1  sin_valid   = 0;
uint1  sout_valid  = 0;

sdram memory(
  clk         <: sdram_clock,
  rst         <: sdram_reset,
  addr        <: saddr,
  wbyte_addr  <: swbyte_addr,
  rw          <: srw,
  data_in     <: sdata_in,
  data_out    :> sdata_out,
  busy        :> sbusy,
  in_valid    <: sin_valid,
  out_valid   :> sout_valid,
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
    swbyte_addr:> swbyte_addr1,
    srw        :> srw1,
    sdata_in   :> sd_in1,
    sdata_out  <: sd_out1,
    sbusy      <: sbusy1,
    sin_valid  :> sin_valid1,
    sout_valid <: sout_valid1  
  );

  uint8 frame  = 0;
  uint8 iter   = 0;

  uint1  vga_vblank_filtered = 0;
  
  vga_vblank_filtered ::= vga_vblank;

  // unused pins
  spi_miso := 1bz;
  avr_rx := 1bz;
  spi_channel := 4bzzzz;

  // ---------- let's go

  // start the switcher
  sd_switcher <- ();
  
  // start the frame drawer
  drawer <- ();
   
  // start the frame buffer row updater
  fbrupd <- ();
 
  // forever
  while (1) {
  
    while (vga_vblank_filtered == 1) { }
    while (vga_vblank_filtered == 0) { }

    led = ~led;
    
  }

}

// ------------------------- 
