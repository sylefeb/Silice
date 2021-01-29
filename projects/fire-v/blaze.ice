// SL 2020-12-02 @sylefeb
//
// Blaze --- a small, fast but limited Risc-V framework in Silice
//  - runs solely in BRAM
//  - access to LEDs and SDCARD
//  - validates at ~100 MHz with a 32KB BRAM
//  - overclocks up to 200 MHz on the ULX3S
//
// Tested on: ULX3S, Verilator, Icarus, IceBreaker
//
// ------------------------- 
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

$$if SIMULATION then
$$verbose = nil
$$end

$$if not (ULX3S or ICARUS or VERILATOR or ICEBREAKER) then
$$error('Sorry, Blaze is currently not supported on this board.')
$$end

$$if ULX3S then
import('plls/pll200.v')
$$end

$$if ICEBREAKER then
$$VGA_VA_END = 400
$include('../common/vga.ice')
import('plls/icebrkr50.v')
import('../common/ice40_half_clock.v')
import('../common/ice40_spram.v')
$$FIREV_NO_INSTRET    = 1
$$FIREV_MERGE_ADD_SUB = nil
$$FIREV_MUX_A_DECODER = 1
$$FIREV_MUX_B_DECODER = 1
$$end

// default palette
$$palette = {}
$$for i=1,256 do
$$  c = (i-1)<<2
$$  palette[i] = (c&255) | ((c&255)<<8) | ((c&255)<<16)
$$end
$$for i=1,64 do
$$  c = (i-1)<<2
$$  palette[64+i] = (c&255)
$$end
$$for i=1,64 do
$$  c = (i-1)<<2
$$  palette[128+i] = (c&255)<<16
$$end
$$for i=1,64 do
$$  c = (i-1)<<2
$$  palette[192+i] = (c&255)<<8
$$end
$$ palette[256] = 255 | (255<<8) | (255<<16)

// pre-compilation script, embeds code within string for BRAM and outputs sdcard image
$$sdcard_image_pad_size = 0
$$dofile('pre/pre_include_asm.lua')

$include('fire-v/fire-v.ice')
$include('ash/bram_ram_32bits.ice')

$include('../common/clean_reset.ice')

$$if VGA and SDCARD then
error('oops, expecting either VGA or SDCARD, not both')
$$end

// ------------------------- 

algorithm main(
  output uint$NUM_LEDS$ leds,
$$if SDCARD then
  output! uint1  sd_clk,
  output! uint1  sd_mosi,
  output! uint1  sd_csn,
  input   uint1  sd_miso,
$$end  
$$if VGA then
  output uint$color_depth$ video_r,
  output uint$color_depth$ video_g,
  output uint$color_depth$ video_b,
  output uint1             video_hs,
  output uint1             video_vs,
$$end
$$if ULX3S then
) <@fast_clock,!fast_reset> {
  uint1 fast_clock = 0;
  uint1 locked     = 0;
  pll pllgen(
    clkin   <: clock,
    clkout0 :> fast_clock,
    locked  :> locked,
  );
  uint1 fast_reset = 0;
  clean_reset rst<!reset>(
    out :> fast_reset
  );
$$elseif ICEBREAKER then
) <@fast_clock> {

  uint1 fast_clock = uninitialized;
  pll pllgen(
    clock_in  <: clock,
    clock_out :> fast_clock,
  );
  
  uint1 vga_clock  = uninitialized;
  ice40_half_clock hc(
    clock_in  <: fast_clock,
    clock_out :> vga_clock,
  );
/*  
  uint1 fast_reset = uninitialized;
  clean_reset rst<@fast_clock,!reset>(
    out :> fast_reset
  );  
  uint1 vga_reset = uninitialized;
  clean_reset rst2<@vga_clock,!reset>(
    out :> vga_reset
  );  
 */
$$else
) {
$$end

  rv32i_ram_io mem;

  uint26 predicted_addr    = uninitialized;
  uint1  predicted_correct = uninitialized;
  uint32 user_data(0);

  // bram io
  bram_ram_32bits bram_ram(
    pram              <:> mem,
    predicted_addr    <:  predicted_addr,
    predicted_correct <:  predicted_correct,
  );

  uint1  cpu_reset      = 1;
  uint26 cpu_start_addr(26h0000000); // NOTE: the BRAM ignores the high part of the address
                                     //       but for bit 32 (mapped memory)
                                     //       26h2000000 is chosen for compatibility with Wildfire

  // cpu 
  rv32i_cpu cpu<!cpu_reset>(
    boot_at          <:  cpu_start_addr,
    user_data        <:  user_data,
    ram              <:> mem,
    predicted_addr    :> predicted_addr,
    predicted_correct :> predicted_correct,
  );

$$if VGA then

  // vga
  uint1  active(0);
  uint1  vblank(0);
  uint10 pix_x(0);
  uint10 pix_y(0);

  vga vga_driver<@vga_clock>(
    vga_hs :> video_hs,
	  vga_vs :> video_vs,
	  active :> active,
	  vblank :> vblank,
	  vga_x  :> pix_x,
	  vga_y  :> pix_y
  );

  uint14 pix_waddr(0);
  uint32 pix_data(0);
  uint1  pix_write(0);
  uint4  pix_mask(0);
  
  uint14 fb0_addr(0);
  uint16 fb0_data_in(0);
  uint1  fb0_wenable(0);
  uint4  fb0_wmask(0);
  uint16 fb0_data_out(0);
  ice40_spram frame0(
    clock    <: vga_clock,
    addr     <: fb0_addr,
    data_in  <: fb0_data_in,
    wenable  <: fb0_wenable,
    wmask    <: fb0_wmask,
    data_out :> fb0_data_out
  );
  uint14 fb1_addr(0);
  uint16 fb1_data_in(0);
  uint1  fb1_wenable(0);
  uint4  fb1_wmask(0);
  uint16 fb1_data_out(0);
  ice40_spram frame1(
    clock    <: vga_clock,
    addr     <: fb1_addr,
    data_in  <: fb1_data_in,
    wenable  <: fb1_wenable,
    wmask    <: fb1_wmask,
    data_out :> fb1_data_out
  );

  bram uint24 palette[256] = {
$$for i=1,256 do
    $palette[i]$,
$$end  
  };
  

  // uint14 pix_fetch := (pix_x[1,9]*50) + pix_y[3,7];
  uint14 pix_fetch := (pix_y[1,9]<<6) + (pix_y[1,9]<<4) + pix_x[3,7];
  // pix_n[3,7] => skipping 1 (240 in 480) then +2 as we pack pixels four by four
  uint10 xprev(0);
  uint1  pix_fb1   := xprev[2,1];
  uint1  pix_hilo  := xprev[1,1];
  
  uint1  pix_wok  ::= (~active & pix_write);
 
$$end

  // sdcard
  uint1  reg_miso(0);

$$if SIMULATION then  
  uint32 iter = 0;
$$end

$$if VGA then
  video_r        := active ? palette.rdata[ 0, 8] : 0;
  video_g        := active ? palette.rdata[ 8,16] : 0;
  video_b        := active ? palette.rdata[16,24] : 0;  
  
  palette.addr   := pix_fb1 ? (fb1_data_out >> {pix_hilo,3b000})
                            : (fb0_data_out >> {pix_hilo,3b000});
  
  fb0_addr       := ~pix_wok ? pix_fetch : pix_waddr;
  fb0_data_in    := pix_data[ 0,16];
  fb0_wenable    := pix_wok;
  fb0_wmask      := {pix_mask[1,1],pix_mask[1,1],pix_mask[0,1],pix_mask[0,1]};
  
  fb1_addr       := ~pix_wok ? pix_fetch : pix_waddr;
  fb1_data_in    := pix_data[16,16];
  fb1_wenable    := pix_wok;
  fb1_wmask      := {pix_mask[3,1],pix_mask[3,1],pix_mask[2,1],pix_mask[2,1]};
  
  pix_write      := pix_wok ? 0 : pix_write;
  
  always_after { xprev = pix_x-1; }
  
$$end

$$if SIMULATION then  
  while (iter != 32768) {
    iter = iter + 1;
$$else
  while (1) {
$$end

    cpu_reset = 0;
$$if SDCARD then
    user_data[3,1] = reg_miso;
    reg_miso       = sd_miso;
$$end
$$if VGA then
    user_data[0,3] = {pix_write,video_vs,1b0};
$$end

    if (mem.addr[28,1] & mem.in_valid & mem.rw) {
//      __display("[iter %d] mem.addr %h mem.data_in %h",iter,mem.addr,mem.data_in);
      if (~mem.addr[3,1]) {
        leds = mem.data_in[0,8];
$$if SIMULATION then            
        __display("[iter %d] LEDs   = %b",iter,leds);
$$end
      } else {
$$if SIMULATION then            
//        __display("[iter %d] mapped = %b",iter,mem.data_in[0,3]);
        __display("[iter %d] pix_waddr = %h, pix_mask %b, px_data %h",iter,mem.addr[ 4,14],mem.addr[20, 4],mem.data_in);
$$end
$$if VGA then
        if (pix_write) {
          leds[0,1] = 1;
        }
        pix_waddr = mem.addr[ 4,14];
        pix_mask  = mem.addr[20, 4];
        pix_data  = mem.data_in;
        pix_write = 1;
$$end
$$if SDCARD then
        // SDCARD
        sd_clk  = mem.data_in[0,1];
        sd_mosi = mem.data_in[1,1];
        sd_csn  = mem.data_in[2,1];
$$end
      }
    }

  }
}

// ------------------------- 
