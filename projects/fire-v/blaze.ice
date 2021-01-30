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
import('plls/icebrkr50.v')
import('../common/ice40_half_clock.v')
import('../common/ice40_spram.v')
$$FIREV_NO_INSTRET    = 1
$$FIREV_MERGE_ADD_SUB = nil
$$FIREV_MUX_A_DECODER = 1
$$FIREV_MUX_B_DECODER = 1
$$end

$$if VGA then

$$VGA_VA_END = 400
$include('../common/vga.ice')

group spram_r32_w32_io
{
  uint14  addr       = 0,
  uint1   rw         = 0,
  uint32  data_in    = 0,
  uint4   wmask      = 0,
  uint1   in_valid   = 0,
  uint32  data_out   = uninitialized,
  uint1   done       = 0
}

// interface for user
interface sdram_user {
  output  addr,
  output  rw,
  output  data_in,
  output  in_valid,
  output  wmask,
  input   data_out,
  input   done,
}

// interface for provider
interface sdram_provider {
  input   addr,
  input   rw,
  input   data_in,
  input   in_valid,
  input   wmask,
  output  data_out,
  output  done
}

$$FLAME_BLAZE = 1
$include('flame/flame.ice')

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

$$if VERILATOR then
import('../common/passthrough.v')
$$config['simple_dualport_bram_wmask_byte_wenable1_width'] = 'data'
algorithm verilator_spram(
  input  uint14 addr,
  input  uint16 data_in,
  input  uint4  wmask,
  input  uint1  wenable,
  output uint16 data_out
) {
  simple_dualport_bram uint16 mem<"simple_dualport_bram_wmask_byte">[16384] = uninitialized;
  always {
    mem.addr0    = addr;
    mem.addr1    = addr;
    mem.wenable1 = {4{wenable}} & wmask;
    mem.wdata1   = data_in;
    data_out     = mem.rdata0;
  }
}
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
$$if VERILATOR then
  output uint1             video_clock,
$$end  
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
) <@vga_clock,!fast_reset> {

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

  uint1 fast_reset = uninitialized;
  clean_reset rst<@fast_clock,!reset>(
    out :> fast_reset
  );
  
  //uint1 vga_reset = uninitialized;
  //clean_reset rst2<@vga_clock,!reset>(
  //  out :> vga_reset
  //);  
$$elseif VERILATOR then
) {
  passthrough p( inv <: clock, outv :> video_clock );
$$else
) {
$$end

$$if VGA then
  spram_r32_w32_io sd;

  uint10  x0      = uninitialized;
  uint10  y0      = uninitialized;
  uint10  x1      = uninitialized;
  uint10  y1      = uninitialized;
  uint10  x2      = uninitialized;
  uint10  y2      = uninitialized;
  int20   ei0     = uninitialized;
  int20   ei1     = uninitialized;
  int20   ei2     = uninitialized;
  uint10  ystart  = uninitialized;
  uint10  ystop   = uninitialized;
  uint8   color   = uninitialized;
  uint1   drawing = uninitialized;
  uint1   triangle_in(0);
  uint1   fbuffer(0);

  flame gpu(
    sd      <:> sd,
    fbuffer <:: fbuffer,
    x0      <:: x0,
    y0      <:: y0,
    x1      <:: x1,
    y1      <:: y1,
    x2      <:: x2,
    y2      <:: y2,
    ei0     <:: ei0,
    ei1     <:: ei1,
    ei2     <:: ei2,
    ystart  <:: ystart,
    ystop   <:: ystop,
    color   <:: color,
    triangle_in <:: triangle_in,
    drawing     :> drawing,
    <:auto:>
  );
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

$$if VERILATOR then
  vga vga_driver(
$$else
  vga vga_driver<@vga_clock>(
$$end  
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
$$if VERILATOR then
  verilator_spram frame0(
$$else  
  ice40_spram frame0(
    clock    <: vga_clock,
$$end
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
$$if VERILATOR then
  verilator_spram frame1(
$$else  
  ice40_spram frame1(
    clock    <: vga_clock,
$$end
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
  
  uint8  frame_fetch_sync(8b1);
  uint2  next_pixel(2b1);
  uint32 four_pixs(0);
  
  // uint14 pix_fetch := (pix_x[1,9]*50) + pix_y[3,7];
  uint14 pix_fetch := (pix_y[1,9]<<6) + (pix_y[1,9]<<4) + pix_x[3,7];
  // pix_n[3,7] => skipping 1 (240 in 480) then +2 as we pack pixels four by four
  
  // we can write whenever the framebuffer is not reading
  uint1  pix_wok  ::= (~frame_fetch_sync[1,1] & pix_write);
  //                                    ^^^ cycle before we need the value
 
$$end

  // sdcard
  uint1  reg_miso(0);

$$if SIMULATION then  
  uint32 iter = 0;
$$end

$$if VGA then
  video_r        := active ? palette.rdata[ 0, 8] : 0;
  video_g        := active ? palette.rdata[ 8, 8] : 0;
  video_b        := active ? palette.rdata[16, 8] : 0;  
  
  palette.addr   := four_pixs;
  
  fb0_addr       := ~pix_wok ? pix_fetch : pix_waddr;
  fb0_data_in    := pix_data[ 0,16];
  fb0_wenable    := pix_wok;
  fb0_wmask      := {pix_mask[1,1],pix_mask[1,1],pix_mask[0,1],pix_mask[0,1]};
  
  fb1_addr       := ~pix_wok ? pix_fetch : pix_waddr;
  fb1_data_in    := pix_data[16,16];
  fb1_wenable    := pix_wok;
  fb1_wmask      := {pix_mask[3,1],pix_mask[3,1],pix_mask[2,1],pix_mask[2,1]};
  
  sd.done        := pix_wok; // TODO: update if CPU writes as well
  pix_write      := pix_wok ? 0 : pix_write;
  
  triangle_in    := 0;
  
  always {
    // updates the four pixels, either reading from spram of shifting them to go to the next one
    // this is controlled through the frame_fetch_sync (8 modulo) and next_pixel (2 modulo)
    // as we render 320x200, there are 8 clock cycles of the 640x480 clock for four frame pixels
    four_pixs = frame_fetch_sync[0,1] 
              ? {fb1_data_out,fb0_data_out} 
              : (next_pixel[0,1] ? (four_pixs >> 8) : four_pixs);
  }
  
  always_after   {
    // updates synchronization variables
    frame_fetch_sync = {frame_fetch_sync[0,1],frame_fetch_sync[1,7]};
    next_pixel       = {next_pixel[0,1],next_pixel[1,1]};
  }
  
$$end

$$if SIMULATION then  
  while (iter != 3276800) {
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
    user_data[0,3] = {pix_write,video_vs,drawing};
$$end

    // leds = sd.addr[0,8];
    if (sd.in_valid) {
      /*__display("(cycle %d) write %h mask %b",iter,sd.addr,sd.wmask);
      if (pix_write) {
        __display("ERROR ##########################################");
      }*/
      pix_waddr = sd.addr;
      pix_mask  = sd.wmask; 
      pix_data  = sd.data_in;
      pix_write = 1;
      leds      = 5b11110;
    } else {
      leds      = 5b0;
    }
    
    
    if (mem.in_valid & mem.rw) {
      switch (mem.addr[27,4]) {
        case 4b1000: {
          // __display("palette %h = %h",mem.addr[2,8],mem.data_in[0,24]);
          //palette.addr1    = mem.addr[2,8];
          //palette.wdata1   = mem.data_in[0,24];
          //palette.wenable1 = 1;
        }
        case 4b0010: {
          switch (mem.addr[2,2]) {
            case 2b00: {
              __display("LEDs = %h",mem.data_in[0,8]);
              leds = mem.data_in[0,8];
            }
$$if VGA then
            case 2b10: {
              __display("PIXELs %h = %h",mem.addr,mem.data_in);
              pix_waddr = mem.addr[ 4,14];
              pix_mask  = mem.addr[20, 4];
              pix_data  = mem.data_in;
              pix_write = 1;
            }        
$$end
            default: { }
          }
        }
        case 4b0001: {
$$if SIMULATION then
          __display("(cycle %d) triangle (%b) = %d %d",iter,mem.addr[2,5],mem.data_in[0,16],mem.data_in[16,16]);
$$end
          switch (mem.addr[2,7]) {
            case 7b0000001: { x0  = mem.data_in[0,16]; y0  = mem.data_in[16,16]; }
            case 7b0000010: { x1  = mem.data_in[0,16]; y1  = mem.data_in[16,16]; }
            case 7b0000100: { x2  = mem.data_in[0,16]; y2  = mem.data_in[16,16]; }
            case 7b0001000: { ei0 = mem.data_in; color = mem.data_in[24,8]; }
            case 7b0010000: { ei1 = mem.data_in; }
            case 7b0100000: { ei2 = mem.data_in; }
            case 7b1000000: { ystart      = mem.data_in[0,16]; 
                              ystop       = mem.data_in[16,16]; 
                              triangle_in = 1;
$$if SIMULATION then
                               __display("new triangle (color %d), cycle %d, %d,%d %d,%d %d,%d",color,iter,x0,y0,x1,y1,x2,y2);
$$end                               
                              }                              
            default: { }
          }      

        }
        default: { }
      }
    }

  }
}

// ------------------------- 
