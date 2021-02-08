// SL 2020-12-02 @sylefeb
//
// Blaze --- VGA + GPU on the IceBreaker
//  - runs solely in BRAM
//  - access to LEDs and SPIFLASH
//
// Tested on: Verilator, IceBreaker
//
// ------------------------- 
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

// ./compile_boot_spiflash.sh ; make icebreaker -f Makefile.blaze

$$if SIMULATION then
$$verbose = nil
$$end

$$if not ((ICEBREAKER and VGA and SPIFLASH) or (VERILATOR and VGA)) then
$$error('Sorry, Blaze is currently not supported on this board.')
$$end

$$if ICEBREAKER then
import('plls/icebrkr50.v')
import('../common/ice40_half_clock.v')
$$FIREV_NO_INSTRET    = 1
$$FIREV_MERGE_ADD_SUB = nil
$$FIREV_MUX_A_DECODER = 1
$$FIREV_MUX_B_DECODER = 1
$$end

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

// default palette
$$palette = {}
$$for i=1,256 do
$$  c = (i-1)
$$  palette[i] = (c&255) | ((c&255)<<8) | ((c&255)<<16)
$$end

// pre-compilation script, embeds code within string for BRAM and outputs sdcard image
$$sdcard_image_pad_size = 0
$$dofile('pre/pre_include_asm.lua')
$$code_size_bytes = init_data_bytes

$include('fire-v/fire-v.ice')
$include('ash/bram_segment_spram_32bits.ice')

$include('../common/clean_reset.ice')

// ------------------------- 

$$if VERILATOR then
import('../common/passthrough.v')
$$end

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

  spram_r32_w32_io sd;

  vertex  v0;
  vertex  v1;
  vertex  v2;
  int20   ei0     = uninitialized;
  int20   ei1     = uninitialized;
  int20   ei2     = uninitialized;
  uint10  ystart  = uninitialized;
  uint10  ystop   = uninitialized;
  uint8   color   = uninitialized;
  uint1   drawing = uninitialized;
  uint1   triangle_in(0);
  uint1   fbuffer(0);
 
  flame_rasterizer gpu_raster(
    sd      <:>  sd,
    fbuffer <::  fbuffer,
    v0      <::> v0,
    v1      <::> v1,
    v2      <::> v2,
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

  transform mx;
  vertex    v;
  vertex    t;
  flame_transform gpu_trsf(
    t  <::> mx,
    v  <::> v,
    tv <::> t,
  );
  uint4 do_transform(0);

  rv32i_ram_io mem;

  uint26 predicted_addr    = uninitialized;
  uint1  predicted_correct = uninitialized;
  uint32 user_data(0);

  uint1            bram_override_we(0);
  uint$bram_depth$ bram_override_addr(0);
  uint32           bram_override_data = uninitialized;

  // CPU RAM
  bram_segment_spram_32bits bram_ram(
    pram               <:> mem,
    predicted_addr     <:  predicted_addr,
    predicted_correct  <:  predicted_correct,
    bram_override_we   <:  bram_override_we,
    bram_override_addr <:  bram_override_addr,
    bram_override_data <:  bram_override_data
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
  
  uint8  frame_fetch_sync_2(                8b1);
  uint16 frame_fetch_sync_4(               16b1);
  uint2  next_pixel_2      (                2b1);
  uint4  next_pixel_4      (                4b1);
  uint32 four_pixs(0);
  
  // buffer 0  320 x 100   
  // buffer 1  160 x 200   
  uint14 pix_fetch := fbuffer
                    ? ((pix_y[2,8]<<6) + (pix_y[2,8]<<4) + pix_x[3,7]       )  // read from 0 (fbuffer == 1)
                    : ((pix_y[1,9]<<5) + (pix_y[1,9]<<3) + pix_x[4,6] + 8000); // read from 1
  // buffer 0
  //  - pix_x[3,7] => half res (320) then +2 as we pack pixels four by four
  //  - pix_y[2,8] => quarter vertical res (100)
  // buffer 1
  //  - pix_x[4,6] => quarter res (160) then +2 as we pack pixels four by four
  //  - pix_y[1,9] => half vertical res (200)
  
  // we can write whenever the framebuffer is not reading
  uint1  pix_wok  ::= fbuffer 
                    ? (~frame_fetch_sync_2[1,1] & pix_write)
                    : (~frame_fetch_sync_4[1,1] & pix_write);
  //                                    ^^^ cycle before we need the value
 
  // spiflash
  uint1  reg_miso(0);

$$if SIMULATION then  
  uint32 iter = 0;
$$end

  //                          vvvvvvvv TODO FIXME this margin should not be needed
  video_r        := (active & pix_x>16) ? palette.rdata[ 0, 8] : 0;
  video_g        := (active & pix_x>16) ? palette.rdata[ 8, 8] : 0;
  video_b        := (active & pix_x>16) ? palette.rdata[16, 8] : 0;  
  
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
    if (fbuffer) {
      four_pixs = frame_fetch_sync_2[0,1] 
                ? {fb1_data_out,fb0_data_out} 
                : (next_pixel_2[0,1] ? (four_pixs >> 8) : four_pixs);      
    } else {    
      four_pixs = frame_fetch_sync_4[0,1] 
                ? {fb1_data_out,fb0_data_out} 
                : (next_pixel_4[0,1] ? (four_pixs >> 8) : four_pixs);
    }
  }
  
  always_after   {
    // updates synchronization variables
    frame_fetch_sync_2 = {frame_fetch_sync_2[0,1],frame_fetch_sync_2[1,7]};
    frame_fetch_sync_4 = {frame_fetch_sync_4[0,1],frame_fetch_sync_4[1,15]};
    next_pixel_2       = {next_pixel_2[0,1],next_pixel_2[1,1]};
    next_pixel_4       = {next_pixel_4[0,1],next_pixel_4[1,3]};
  }

$$if SIMULATION then  
  while (iter != 1600000) {
    iter = iter + 1;
$$else
  while (1) {
$$end

    cpu_reset = 0;

    user_data[0,4] = {reg_miso,pix_write,vblank,drawing};
$$if SPIFLASH then    
    reg_miso       = sf_miso;
$$end

    if (sd.in_valid) {
      /*__display("(cycle %d) write %h mask %b",iter,sd.addr,sd.wmask);
      if (pix_write) {
        __display("ERROR ##########################################");
      }*/
      pix_waddr = sd.addr;
      pix_mask  = sd.wmask; 
      pix_data  = sd.data_in;
      pix_write = 1;
    }
    
    if (do_transform[0,1]) {
      // transform is done, write back result
      __display("transform done, write back %d,%d,%d at @%h  (%h)",t.x,t.y,t.z,bram_override_addr,{2b00,t.z,t.y,t.x});
      bram_override_we   = 1;
      bram_override_data = {2b00,t.z,t.y,t.x};
      do_transform       = 0;
    } else {
      bram_override_we   = 0;
      do_transform       = do_transform >> 1;
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
            case 2b01: {
              __display("swap buffers");
              fbuffer = ~fbuffer;
            }            
            case 2b10: {
              // SPIFLASH
$$if SIMULATION then
              __display("(cycle %d) SPIFLASH %b",iter,mem.data_in[0,3]);
$$end              
$$if SPIFLASH then
              sf_clk  = mem.data_in[0,1];
              sf_mosi = mem.data_in[1,1];
              sf_csn  = mem.data_in[2,1];              
$$end              
            }        
            case 2b11: {           
              pix_waddr = mem.addr[ 4,14];
              pix_mask  = mem.addr[20, 4];
              pix_data  = mem.data_in;
              pix_write = 1;
              // __display("PIXELs @%h wm:%b %h",pix_waddr,pix_mask,pix_data);
            }
            default: { }
          }
        }
        case 4b0001: {
$$if SIMULATION then
//          __display("(cycle %d) triangle (%b) = %d %d",iter,mem.addr[2,5],mem.data_in[0,16],mem.data_in[16,16]);
$$end
          switch (mem.addr[2,4]) {
            case 0:  { v0.x = mem.data_in[0,10]; v0.y = mem.data_in[10,10]; v0.z = mem.data_in[20,10]; }
            case 1:  { v1.x = mem.data_in[0,10]; v1.y = mem.data_in[10,10]; v1.z = mem.data_in[20,10]; }
            case 2:  { v2.x = mem.data_in[0,10]; v2.y = mem.data_in[10,10]; v2.z = mem.data_in[20,10]; }
            case 3:  { ei0 = mem.data_in;        color = mem.data_in[24,8]; }
            case 4:  { ei1 = mem.data_in; }
            case 5:  { ei2 = mem.data_in;
                      ystart      = v0.y; 
                      ystop       = v2.y; 
                      triangle_in = 1;
$$if SIMULATION then
                      __display("(cycle %d) new triangle, color %d, (%d,%d) (%d,%d) (%d,%d)",iter,color,v0.x,v0.y,v1.x,v1.y,v2.x,v2.y);
$$end                               
                     }
            case 7:  {
                        mx.m00 = mem.data_in[0,8]; mx.m01 = mem.data_in[8,8]; mx.m02 = mem.data_in[16,8]; 
                     }
            case 8:  {
                        mx.m10 = mem.data_in[0,8]; mx.m11 = mem.data_in[8,8]; mx.m12 = mem.data_in[16,8];
                     }
            case 9:  {
                        mx.m20 = mem.data_in[0,8]; mx.m21 = mem.data_in[8,8]; mx.m22 = mem.data_in[16,8];
                     }
            case 10: {
                        mx.tx  = mem.data_in[0,10]; mx.ty = mem.data_in[16,10];
                     }
            case 11: {
                       bram_override_addr = $(1<<bram_depth)-1$;
$$if SIMULATION then
                       __display("(cycle %d) bram write back addr reset %h",iter,bram_override_addr);
$$end                               
                     }
            case 12: {
                        v.x = mem.data_in[0,10]; v.y = mem.data_in[10,10]; v.z = mem.data_in[20,10];
                        do_transform       = 4b1000;
                        bram_override_addr = bram_override_addr + 1;
$$if SIMULATION then
                      __display("(cycle %d) transform %d,%d,%d",iter,v.x,v.y,v.z);
                      __display("mx %d,%d,%d",mx.m00,mx.m01,mx.m02);
                      __display("mx %d,%d,%d",mx.m10,mx.m11,mx.m12);
                      __display("mx %d,%d,%d",mx.m20,mx.m21,mx.m22);
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
