// SL 2021-03-26 @sylefeb
//
// VGA + RISC-V 'Voxel Space' terrain renderer on the IceBreaker
//
// Tested on: Verilator, IceBreaker
//
// ------------------------- 
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

// ./build.sh

$$if SIMULATION then
$$verbose = nil
$$end

$$if not ((ICEBREAKER and VGA and SPIFLASH) or (VERILATOR and VGA)) then
$$error('Sorry, currently not supported on this board.')
$$end

$$if ICEBREAKER then
import('../common/ice40_half_clock.v')
import('../fire-v/plls/icebrkr50.v')
$$FIREV_NO_INSTRET    = 1
$$FIREV_MERGE_ADD_SUB = nil
$$FIREV_MUX_A_DECODER = 1
$$FIREV_MUX_B_DECODER = 1
$$end

$$VGA_VA_END = 400
$include('../common/vga.ice')

$$div_width = 24
$include('../common/divint_std.ice')

// group for frame buffer interface
group fb_r16_w16_io
{
  uint14  addr       = 0,
  uint1   rw         = 0,
  uint16  data_in    = 0,
  uint4   wmask      = 0,
  uint1   in_valid   = 0,
  uint16  data_out   = uninitialized,
}

// interface for frame buffer user 
interface fb_user {
  output  addr,
  output  rw,
  output  data_in,
  output  in_valid,
  output  wmask,
  input   data_out,
}

$$palette    = get_palette_as_table('data/color6.tga')

// pre-compilation script, embeds code within string for BRAM and outputs sdcard image
$$sdcard_image_pad_size = 0
$$dofile('../fire-v/pre/pre_include_asm.lua')
$$code_size_bytes = init_data_bytes

$include('../fire-v/fire-v/fire-v.ice')
$include('../fire-v/ash/bram_ram_32bits.ice')
$include('../common/clean_reset.ice')

import('../common/ice40_spram.v')

// ------------------------- 

$$if VERILATOR then
import('../common/passthrough.v')
$include('../fire-v/ash/verilator_spram.ice')
$$end

// ------------------------- 
   
$$div_width    = 48
$$div_unsigned = 1
$include('../common/divint_std.ice')

// ------------------------- 

$include('terrain_renderer.ice')

// ------------------------- 

algorithm main(
  output uint$NUM_LEDS$    leds,
  output uint$color_depth$ video_r,
  output uint$color_depth$ video_g,
  output uint$color_depth$ video_b,
  output uint1             video_hs,
  output uint1             video_vs,
$$if VERILATOR then
  output uint1             video_clock,
$$end  
$$if SPIFLASH then
  output uint1             sf_clk,
  output uint1             sf_csn,
  output uint1             sf_mosi,
  input  uint1             sf_miso,
$$end  
$$if NUM_BTNS then
  input  uint$NUM_BTNS$    btns,
$$end  
$$if ICEBREAKER then
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
$$elseif VERILATOR then
) {
  passthrough p( inv <: clock, outv :> video_clock );
$$else
) {
$$end

$$if not NUM_BTNS then
  uint3 btns(0); // placeholder for buttons
$$end  

  rv32i_ram_io mem;

  uint26 predicted_addr    = uninitialized;
  uint1  predicted_correct = uninitialized;
  uint32 user_data(0);

  // CPU RAM
  bram_ram_32bits bram_ram(
    pram               <:> mem,
    predicted_addr     <:  predicted_addr,
    predicted_correct  <:  predicted_correct,
  );

  uint1  cpu_reset      = 1;
  uint26 cpu_start_addr(26h0010000); // NOTE: this starts in the boot sector
  
  // cpu 
  rv32i_cpu cpu<!cpu_reset>(
    boot_at          <:  cpu_start_addr,
    user_data        <:  user_data,
    ram              <:> mem,
    predicted_addr    :> predicted_addr,
    predicted_correct :> predicted_correct,
  );

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
  uint16 pix_data(0);
  uint1  pix_write(0);
  uint4  pix_mask(0);
  
  // Each frame buffer holds a 320x200 4bpp frame.
  // Framebuffer 0 is in SPRAM 0, framebuffer 1 in SPRAM 1.
  //
  // This means we can read/write 4 pixels at once.
  // As we generate a 640x480 signal we have to read every 8 VGA pixels along a row.
  //
  // (Blaze goes up to eight at the cost of a more complex addressing
  //  and sharing write/reads, here we keep things simpler.)
  //
  // Frame buffer 0: [0,15999]
  // Frame buffer 1: [0,15999]
  //
  // Writes always occur into the framebuffer not being displayed.
  
  // SPRAM 0 for framebuffers
  uint14 fb0_addr(0);
  uint16 fb0_data_in(0);
  uint1  fb0_wenable(0);
  uint8  fb0_wmask(0);
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
  
  // SPRAM 1 for framebuffers  
  uint14 fb1_addr(0);
  uint16 fb1_data_in(0);
  uint1  fb1_wenable(0);
  uint8  fb1_wmask(0);
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

  // SPRAM for packed color + heightmap
  // - height [0, 8]
  // - color  [8,12]
  // NOTE: 4 bits are unused
  //
  // -> write to maps (loading data)
  uint1  map_write(0);
  uint1  map_select(0);
  uint14 map_waddr(0);
  uint16 map_data(0);
  // -> map0
  uint14 map0_raddr(0);
  uint1  map0_write   := (map_write & ~map_select);
  uint14 map0_addr    := map0_write ? map_waddr : map0_raddr;
  uint1  map0_wenable := map0_write;
  uint4  map0_wmask   := 4b1111;
  uint16 map0_data_out(0);
$$if VERILATOR then
  verilator_spram map0(
$$else  
  ice40_spram map0(
    clock    <: vga_clock,
$$end
    addr     <: map0_addr,
    data_in  <: map_data,
    wenable  <: map0_wenable,
    wmask    <: map0_wmask,
    data_out :> map0_data_out
  );

  // ==== voxel space renderer instantiation
  // interface for GPU writes in framebuffer
  fb_r16_w16_io fb;
  uint1 fbuffer(0);    // frame bnuffer selected for display (writes can occur in ~fbuffer)  
  uint4 sky_pal_id(0); // sky palette id
  terrain_renderer vs(
    fb          <:> fb,
    fbuffer      :> fbuffer,
    sky_pal_id   <: sky_pal_id,
    btns         <: r_btns,
    map0_raddr   :> map0_raddr,
    map0_rdata   <: map0_data_out
  );

  simple_dualport_bram uint24 palette[16] = {
$$for i=1,16 do
//      $(i-1)*16$,
    $palette[i]$,
$$end  
  };
  
  uint8  frame_fetch_sync(                8b1);
  uint2  next_pixel      (                2b1);
  uint16 four_pixs(0);
  
  // buffers are 320 x 200, 4bpp
  uint14 pix_fetch(0);
  uint14 last_fetch(0);
  uint1  next_frame(0); // true when waiting for next frame

  //  - pix_x[3,7] => read every 8 VGA pixels
  //  - pix_y[1,9] => half VGA vertical res (200)
  
  // spiflash
  uint1  reg_miso(0);

$$if SIMULATION then  
  uint32 iter = 0;
$$end

  // register input buttons
  uint3 r_btns(0);
  r_btns        ::= btns;

  next_frame := (~active) ? next_frame : ( pix_x == 639 && pix_y == 399 ? 1 : 0 ); // waiting for next frame?
  pix_fetch  := (active) ? (pix_y[1,9]<<6) + (pix_y[1,9]<<4) + pix_x[3,7] + 1 // prefetch before needed on screen!
                         : (~next_frame 
                            ? (pix_y[0,1] ? last_fetch - 80 : last_fetch)     // prefetch next line, depends on y parity
                          : 0);                                               // prefetch next frame, first top left corner pixel
  last_fetch := (active) ? pix_fetch : last_fetch; // tracks last fetched address before going out of frame

  video_r        := (active) ? palette.rdata0[ 2, 6] : 0;
  video_g        := (active) ? palette.rdata0[10, 6] : 0;
  video_b        := (active) ? palette.rdata0[18, 6] : 0;  
  
  fb0_addr       := ~fbuffer ? pix_fetch : pix_waddr;
  fb0_data_in    := pix_data;
  fb0_wenable    := pix_write & fbuffer;
  fb0_wmask      := pix_mask;
  
  fb1_addr       := fbuffer  ? pix_fetch : pix_waddr;
  fb1_data_in    := pix_data;
  fb1_wenable    := pix_write & ~fbuffer;
  fb1_wmask      := pix_mask;
  
  map_write      := 0; // reset map write
  pix_write      := 0; // reset pix_write
  
  always_before {    
__display("active: %b fetch: %b next: %b x: %d y: %d addr: %h vs: %b hs: %b vb: %b nf: %b",active,frame_fetch_sync[0,1],next_pixel[0,1],pix_x,pix_y,pix_fetch,video_vs,video_hs,vblank,next_frame);
    // updates the four pixels, either reading from spram of shifting them to go to the next one
    // this is controlled through the frame_fetch_sync (8 modulo) and next_pixel (2 modulo)
    // as we render 320x200 4bpp, there are 8 clock cycles of the 640x480 clock for four frame pixels    
    four_pixs = frame_fetch_sync[0,1]
              ? (~fbuffer        ? fb0_data_out     : fb1_data_out)
              : (next_pixel[0,1] ? (four_pixs >> 4) : four_pixs);      

    // query palette, pixel will be shown next cycle
    // NOTE: we are loosing the first column, but let's keep things simple!
    palette.addr0 = four_pixs[0,4];  

  }
  
  always_after   {
    // updates synchronization variables
    frame_fetch_sync = active ? {frame_fetch_sync[0,1],frame_fetch_sync[1,7]} : 8b00000001;
    next_pixel       = active ? {next_pixel[0,1],next_pixel[1,1]}             : 2b01;
  }

$$if SIMULATION then  
  while (iter != 960000) {
    iter = iter + 1;
$$else
  while (1) {
$$end

    cpu_reset = 0;

    user_data[0,7] = {r_btns,reg_miso,pix_write,vblank,1b0};

$$if SPIFLASH then    
    reg_miso       = sf_miso;
$$end

    if (fb.in_valid) {
      // __display("(cycle %d) write @%d mask %b",iter,fb.addr,fb.wmask);
      pix_waddr = fb.addr;
      pix_mask  = fb.wmask; 
      pix_data  = fb.data_in;
      pix_write = 1;
    }
    
    if (mem.in_valid & mem.rw) {
      switch (mem.addr[27,4]) {
        case 4b1000: {
          // __display("palette %h = %h",mem.addr[2,8],mem.data_in[0,24]);
          palette.addr1    = mem.addr[2,4];
          palette.wdata1   = mem.data_in[0,24];
          palette.wenable1 = 1;
          sky_pal_id       = mem.data_in[24,1] ? mem.addr[2,4] : sky_pal_id;
        }
        case 4b0010: {
          switch (mem.addr[2,2]) {
            case 2b00: {
              __display("LEDs = %h",mem.data_in[0,8]);
              leds = mem.data_in[0,8];
            }
            case 2b01: { 
              /* swap buffer ignored */ 
              }
            case 2b10: {
              // SPIFLASH
$$if SPIFLASH then
              sf_clk  = mem.data_in[0,1];
              sf_mosi = mem.data_in[1,1];
              sf_csn  = mem.data_in[2,1];              
$$end              
            }        
            case 2b11: {           
              pix_waddr = mem.addr[ 4,14];
              pix_mask  = mem.addr[18, 4];
              pix_data  = mem.data_in;
              pix_write = 1;
              // __display("PIXELs @%h wm:%b %h",pix_waddr,pix_mask,pix_data);
            }
            default: { }
          }
        }
        case 4b0001: {
          map_write  = 1;
          map_data   = mem.data_in[ 0,16];
          map_waddr  = mem.data_in[16,14];
          map_select = mem.data_in[30, 1];          
        }
        default: { }
      }
    }

  }
}

// ------------------------- 
