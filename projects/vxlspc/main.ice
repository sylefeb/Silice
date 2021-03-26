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

$$palette = get_palette_as_table('data/color.tga')

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

$$fp           = 11
$$fp_scl       = 1<<fp
$$one_over_width = fp_scl//320  
$$z_step       = fp_scl
$$z_num_step   = 128
    
$$div_width    = 48
$$div_unsigned = 1
$include('../common/divint_std.ice')

// ------------------------- 

algorithm vxlspc(
    fb_user        fb,
    output  uint1  fbuffer = 0,
    output! uint14 map0_raddr,
    input   uint16 map0_rdata,
    output! uint14 map1_raddr,
    input   uint16 map1_rdata,
) <autorun> {

  int24  z(0); // 12.12 fp
  int24  l_x(0);
  int24  l_y(0);
  int24  r_x(0);
  int24  r_y(0);
  int24  dx(0);
  int24  inv_z(0);
  int24  offs(0);
  uint10 x(0);

  uint24 one = $fp_scl*fp_scl - 1$;
  div48 div(
    inum <:: one,
    iden <:: z,
  );
  
  fb.in_valid := 0;

  while (1) {
  
    uint8 iz = 0;
  __display("--------- frame ------------");
    z = $z_step * z_num_step + z_step * 8$;
    while (iz != $z_num_step$) {
      l_x   = $128*fp_scl + 63*fp_scl$        - (z>>1);
      l_y   = $128*fp_scl + 63*fp_scl$ + offs + (z>>1);
      r_x   = $128*fp_scl + 63*fp_scl$        + (z>>1);
      r_y   = $128*fp_scl + 63*fp_scl$ + offs + (z>>1);      
      dx    = ((r_x - l_x) * $one_over_width$) >> $fp$;
__display("z: %d [l_x: %d r_x: %d] y: %d dx: %d",z,l_x>>>$fp$,r_x>>>$fp$,l_y>>>$fp$,dx);
//__display("dx: %d", dx);
      (inv_z) <- div <- ();
//__display("z: %d inv_z: %d", z, inv_z);
      x     = 0;
__write("[");
      while (x != 320) {
        int11 y_ground = uninitialized;
        int11 y        = uninitialized;
        uint1 in_sky   = 0;
        int24 hmap     = uninitialized;
        hmap     = map0_rdata[0,8];
        y_ground = (((128 - hmap) * inv_z) >>> $fp-5$) + 64;
++:        
        y_ground = (iz == 0) ? 0 : ((y_ground < 0) ? 0 : ((y_ground > 199) ? 199 : y_ground));
// __display("column [0,%d]", y_ground);
//__write("%d,", y_ground);
        y = 199;
        while (y != y_ground) {
          fb.rw       = 1;
          fb.data_in  = (iz == 0) ? 2 : ((map0_rdata[8,4]) << ({x[0,2],2b0}));
          fb.wmask    = 1 << x[0,2];
          fb.in_valid = 1;
          fb.addr     = (x >> 2) + (y << 6) + (y << 4);  //  320 x 200, 4bpp    x>>2 + y*80          
          y = y - 1;
        }
        x   = x + 1;
        l_x = l_x + dx;
        map0_raddr = {l_y[$fp$,7],l_x[$fp$,7]};
        __write("%d,", l_x[$fp$,7]);
      }      
__display("]");
      z  = z - $z_step$;
      iz = iz + 1;
    }
    fbuffer = ~fbuffer;
    offs    = offs + $fp_scl$;
  }

/*
  always {    
    
    fb.rw       = 1;
    fb.data_in  = ((map0_rdata[8,4]) << ({x[0,2],2b0}));
    fb.wmask    = 1 << x[0,2];
    fb.in_valid = 1;
    fb.addr     = (x >> 2) + (y << 6) + (y << 4);  //  320 x 200, 4bpp    x>>2 + y*80
            
    y     = (x == 319) ? ( y == 199 ? 0 : (y+1) ) : y;
    x     = (x == 319) ? 0 : (x+1);
    
    // read next
    map0_raddr  = {y[0,7],x[0,7]};

    // __display("x=%d y=%d",x,y);
  }
*/
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
  uint16 pix_data(0);
  uint1  pix_write(0);
  uint4  pix_mask(0);
  
  /*
  
    Each frame buffer holds a 320x200 4bpp frame
    Framebuffer 0 is in SPRAM 0, framebuffer 1 in SPRAM 1

    This means we can read/write 4 pixels at once
    As we generate a 640x480 signal we have to read every 8 VGA pixels along a row

    (Blaze goes up to height at the cost of a more complex addressing
     and sharing write/reads, here we keep things simpler)
      
    Frame buffer 0: [0,15999]
    Frame buffer 1: [0,15999]
    
    Writes always occur into the framebuffer not being displayed.
    
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
  // map0 contains a first  128x128 map
  // map1 contains a second 128x128 map
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
  fb_r16_w16_io fb;
  
  uint1 fbuffer(0); // frame bnuffer selected for display (writes can occur in ~fbuffer)
  
  vxlspc vs(
    fb          <:> fb,
    fbuffer      :> fbuffer,
    map0_raddr   :> map0_raddr,
    map0_rdata   <: map0_data_out,
    map1_raddr   :> map1_raddr,
    map1_rdata   <: map1_data_out,
  );

  bram uint24 palette[16] = {
$$for i=1,16 do
    $palette[i]$,
$$end  
  };
  
  uint8  frame_fetch_sync(                8b1);
  uint2  next_pixel      (                2b1);
  uint16 four_pixs(0);
  
  // buffers are 320 x 200, 4bpp
  uint14 pix_fetch := (pix_y[1,9]<<6) + (pix_y[1,9]<<4) + pix_x[3,7];

  //  - pix_x[3,7] => read every 8 VGA pixels
  //  - pix_y[1,9] => half VGA vertical res (200)
  
  // spiflash
  uint1  reg_miso(0);

$$if SIMULATION then  
  uint32 iter = 0;
$$end

  leds           := {4b0,fbuffer};

  video_r        := (active) ? palette.rdata[ 2, 6] : 0;
  video_g        := (active) ? palette.rdata[10, 6] : 0;
  video_b        := (active) ? palette.rdata[18, 6] : 0;  
  
  palette.addr   := four_pixs[0,4];
  
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
  
  always {
    // updates the four pixels, either reading from spram of shifting them to go to the next one
    // this is controlled through the frame_fetch_sync (8 modulo) and next_pixel (2 modulo)
    // as we render 320x200 4bpp, there are 8 clock cycles of the 640x480 clock for four frame pixels
    four_pixs = frame_fetch_sync[0,1]
              ? (~fbuffer        ? fb0_data_out     : fb1_data_out)
              : (next_pixel[0,1] ? (four_pixs >> 4) : four_pixs);      
  }
  
  always_after   {
    // updates synchronization variables
    frame_fetch_sync = {frame_fetch_sync[0,1],frame_fetch_sync[1,7]};
    next_pixel       = {next_pixel[0,1],next_pixel[1,1]};
  }

$$if SIMULATION then  
  while (iter != 3200000) {
    iter = iter + 1;
$$else
  while (1) {
$$end

    cpu_reset = 0;

    user_data[0,5] = {1b0,reg_miso,pix_write,vblank,1b0};

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
              // leds = mem.data_in[0,8];
            }
            case 2b01: {
              // __display("swap buffers");
              // fbuffer = ~fbuffer;
            }            
            case 2b10: {
              // SPIFLASH
$$if SIMULATION then
              // __display("(cycle %d) SPIFLASH %b",iter,mem.data_in[0,3]);
$$end              
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
