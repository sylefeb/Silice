// SL 2020-12-02 @sylefeb
//
// VGA + RISC-V 'Voxel Space' on the IceBreaker
//
// Tested on: Verilator, IceBreaker
//
// ------------------------- 
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

// ./compile_boot_spiflash.sh ; make icebreaker


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

group spram_r32_w32_io
{
  uint14  addr       = 0,
  uint1   rw         = 0,
  uint32  data_in    = 0,
  uint8   wmask      = 0,
  uint1   in_valid   = 0,
  uint32  data_out   = uninitialized,
  uint1   done       = 0
}

// (SD)RAM interface for user 
// NOTE: there is no SDRAM in this design, but we hijack
//       the interface for easier portability
interface sdram_user {
  output  addr,
  output  rw,
  output  data_in,
  output  in_valid,
  output  wmask,
  input   data_out,
  input   done,
}

$$palette={}
$$for i = 1,256 do palette[i]=(i-1)|((i-1)<<8)|((i-1)<<16) end

$$for i = 1,16 do
$$ print('r = ' .. (palette[i*16]&255) .. ' g = ' .. ((palette[i*16]>>8)&255)  .. ' b = ' .. ((palette[i*16]>>16)&255))
$$end

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

algorithm vxlspc(
    sdram_user     sd,
    input   uint1  fbuffer,
    output! uint14 map0_raddr,
    input   uint16 map0_rdata,
    output! uint14 map1_raddr,
    input   uint16 map1_rdata,
) <autorun> {

  uint10 x(0);
  uint10 y(0); 
  //  320 x 200, 4bpp    x>>2 + y*80
  uint14 addr ::= x[3,7] + (y << 5) + (y << 3) + (~fbuffer ? 0 : 8000);
  
  uint1 ready(1);
  
  always {
    sd.rw       = 1;
    sd.data_in  = 32hfedcba9;
    sd.wmask    = 8b11111111;
    sd.in_valid = ready;
    sd.addr     = addr;
    if (sd.done) {
      y     = (x == 316) ? ( y == 199 ? 0 : (y+1) ) : y;
      x     = (x == 316) ? 0 : (x+4);
      //__display("x=%d y=%d",x,y);
      ready = 1;
    }
  }
  
}

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
  
$$elseif VERILATOR then
) {
  passthrough p( inv <: clock, outv :> video_clock );
$$else
) {
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
  uint32 pix_data(0);
  uint1  pix_write(0);
  uint8  pix_mask(0);
  
  /*
    Each frame buffer holds a 320x200 4bpp frame
    
    Each frame buffer uses both SPRAM for wider throughput:
      SPRAM0 : 16 bits => 4 pixels
      SPRAM1 : 16 bits => 4 pixels
      So we get eight pixels at each read      
      As we generate a 640x480 signal we have to read every 16 VGA pixels along a row
      
    Frame buffer 0: [    0,7999]
    Frame buffer 1: [8000,15999]
  */
  
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

  // SPRAMs for packed color + heightmap
  // - height [0, 8]
  // - color  [8,12]
  // NOTE: 4 bits are unused
  // map0 contains 128x64 top half
  // map1 contains 128x64 bottom half
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
  // -> map1
  uint14 map1_raddr(0);
  uint1  map1_write   := (map_write & map_select);
  uint14 map1_addr    := map1_write ? map_waddr : map1_raddr;
  uint1  map1_wenable := map1_write;
  uint4  map1_wmask   := 4b1111;
  uint16 map1_data_out(0);
$$if VERILATOR then
  verilator_spram map1(
$$else  
  ice40_spram map1(
    clock    <: vga_clock,
$$end
    addr     <: map1_addr,
    data_in  <: map_data,
    wenable  <: map1_wenable,
    wmask    <: map1_wmask,
    data_out :> map1_data_out
  );

  // interface for GPU writes in framebuffer
  spram_r32_w32_io sd;
  
  vxlspc vs(
    sd          <:> sd,
    fbuffer     <:: fbuffer,
    map0_raddr   :> map0_raddr,
    map0_rdata   <: map0_data_out,
    map1_raddr   :> map1_raddr,
    map1_rdata   <: map1_data_out,
  );

  bram uint24 palette[16] = {
$$for i=1,16 do
    $palette[i*16]$,
$$end  
  };
  
  uint16 frame_fetch_sync(               16b1);
  uint2  next_pixel      (                2b1);
  uint32 eight_pixs(0);
  
  uint1 fbuffer(0);
  
  // buffers are 320 x 200, 4bpp
  uint14 pix_fetch := (pix_y[1,9]<<5) + (pix_y[1,9]<<3) + pix_x[4,6] + (fbuffer ? 0 : 8000);

  //  - pix_x[4,6] => read every 16 VGA pixels
  //  - pix_y[1,9] => half vertical res (200)
  
  // we can write whenever the framebuffer is not reading
  uint1  pix_wok  ::= (~frame_fetch_sync[1,1] & pix_write);
  //                                    ^^^ cycle before we need the value
 
  // spiflash
  uint1  reg_miso(0);

$$if SIMULATION then  
  uint32 iter = 0;
$$end

  video_r        := (active) ? palette.rdata[ 2, 6] : 0;
  video_g        := (active) ? palette.rdata[10, 6] : 0;
  video_b        := (active) ? palette.rdata[18, 6] : 0;  
  
  palette.addr   := eight_pixs[0,4];
  
  fb0_addr       := ~pix_wok ? pix_fetch : pix_waddr;
  fb0_data_in    := pix_data[ 0,16];
  fb0_wenable    := pix_wok;
  fb0_wmask      := {pix_mask[3,1],pix_mask[2,1],pix_mask[1,1],pix_mask[0,1]};
  
  fb1_addr       := ~pix_wok ? pix_fetch : pix_waddr;
  fb1_data_in    := pix_data[16,16];
  fb1_wenable    := pix_wok;
  fb1_wmask      := {pix_mask[7,1],pix_mask[6,1],pix_mask[5,1],pix_mask[4,1]};
  
  sd.done        := pix_wok; // TODO: update if CPU writes as well
  pix_write      := pix_wok ? 0 : pix_write;
  map_write      := 0;
  
  always {
    // updates the eight pixels, either reading from spram of shifting them to go to the next one
    // this is controlled through the frame_fetch_sync (16 modulo) and next_pixel (2 modulo)
    // as we render 320x200 4bpp, there are 16 clock cycles of the 640x480 clock for eight frame pixels
    eight_pixs = frame_fetch_sync[0,1]
              ? {fb1_data_out,fb0_data_out} 
              : (next_pixel[0,1] ? (eight_pixs >> 4) : eight_pixs);      
  }
  
  always_after   {
    // updates synchronization variables
    frame_fetch_sync = {frame_fetch_sync[0,1],frame_fetch_sync[1,15]};
    next_pixel       = {next_pixel[0,1],next_pixel[1,1]};
  }

$$if SIMULATION then  
  while (iter != 320000) {
    iter = iter + 1;
$$else
  while (1) {
$$end

    cpu_reset = 0;

    user_data[0,5] = {1b0,reg_miso,pix_write,vblank,1b0};
$$if SPIFLASH then    
    reg_miso       = sf_miso;
$$end

    if (sd.in_valid) {
      //__display("(cycle %d) write %h mask %b",iter,sd.addr,sd.wmask);
      //if (pix_write) {
      //  __display("ERROR ##########################################");
      //}
      pix_waddr = sd.addr;
      pix_mask  = sd.wmask; 
      pix_data  = sd.data_in;
      pix_write = 1;
    }
    
    if (mem.in_valid & mem.rw) {
      switch (mem.addr[27,4]) {
        case 4b1000: {
          // __display("palette %h = %h",mem.addr[2,8],mem.data_in[0,24]);
          // TODO FIXME: yosys fails to infer simple_dual_port on palette, investigate
          /*
          palette.addr1    = mem.addr[2,8];
          palette.wdata1   = mem.data_in[0,24];
          palette.wenable1 = 1;
          */
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
              pix_mask  = mem.addr[18, 8];
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
