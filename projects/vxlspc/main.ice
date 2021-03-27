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

$$sky_pal_id     = 2

$$fp             = 11
$$fp_scl         = 1<<fp
$$one_over_width = fp_scl//320  
$$z_step         = fp_scl
$$z_num_step     = 256
    
$$div_width    = 48
$$div_unsigned = 1
$include('../common/divint_std.ice')

// ------------------------- 

//////////////////////////////////////////////
// interpolator
// computes the interpolation from a to b
// according to i in [0,255]
// maps to DSP blocks
//////////////////////////////////////////////

algorithm interpolator(
  input  uint8 a,
  input  uint8 b,
  input  uint8 i,
  output uint8 v
) <autorun> {
  always {
    v = ( (b * i) + (a * (255 - i)) ) >> 8;
  }  
}

//////////////////////////////////////////////
// voxel space renderer
// - this is similar but not quite exactly the same
//   as the famous Voxel Space engine from Novalogic
//   see e.g. https://github.com/s-macke/VoxelSpace
// - the key different lies in the in interpolation
//   that takes place for height and color
//////////////////////////////////////////////

algorithm vxlspc(
    fb_user        fb,
    output  uint1  fbuffer = 0,
    input   uint3  btns,
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
  int24  v_x($(128   )*fp_scl$);
  int24  v_y($(128+63)*fp_scl$);
  uint8  vheight(0);
  uint8  gheight(0);
  uint10 x(0);
  uint12 h(0);

  uint8 interp_a(0);
  uint8 interp_b(0);
  uint8 interp_i(0);
  uint8 interp_v(0);
  interpolator interp(
    a <: interp_a,
    b <: interp_b,
    i <: interp_i,
    v :> interp_v
  );

  // https://en.wikipedia.org/wiki/Ordered_dithering
  int6 bayer_8x8[64] = {
    0, 32, 8, 40, 2, 34, 10, 42,
    48, 16, 56, 24, 50, 18, 58, 26,
    12, 44, 4, 36, 14, 46, 6, 38,
    60, 28, 52, 20, 62, 30, 54, 22,
    3, 35, 11, 43, 1, 33, 9, 41,
    51, 19, 59, 27, 49, 17, 57, 25,
    15, 47, 7, 39, 13, 45, 5, 37,
    63, 31, 55, 23, 61, 29, 53, 21
  }; 

  // 1/n table for vertical interpolation  
  bram uint10 inv_n[128]={
    0, // 0: unused
$$for n=1,127 do
    $1023 // n$, // the double slash in Lua pre-processor is tne integer division
$$end
  };

  bram uint8 y_last[320] = uninitialized;

  uint24 one = $fp_scl*fp_scl$;
  div48 div(
    inum <:: one,
    iden <:: z,
  );
  
  // register input buttons
  uint3 r_btns(0);
  r_btns        ::= btns;

  fb.in_valid    := 0;
  y_last.wenable := 0;
  y_last.addr    := x;

  while (1) {
  
    uint9 iz   = 0;
    z          = $z_step * 6$;
    // sample ground height
    map0_raddr = {v_y[$fp$,7],v_x[$fp$,7]};
++:
    gheight    = map0_rdata[0,8];
    // adjust view height
    // NOTE: this below is very expensive in size due to < >
    vheight    = (vheight < gheight) ? vheight + 3 : ((vheight > gheight) ? vheight - 1 : vheight);
    while (iz != $z_num_step$) {
      uint12 h00(0); uint12 h10(0); 
      uint12 h11(0); uint12 h01(0);
      // generate frustum coordinates
      l_x   = v_x - (z);
      l_y   = v_y + (z);
      r_x   = v_x + (z);
      r_y   = v_y + (z);      
      // generate sampling increment along z-iso
      dx    = ((r_x - l_x) * $one_over_width$) >>> $fp$;
      // compute z inverse  TODO: this can be done in parallel for next row
      (inv_z) <- div <- ();
      // go through screen columns
      x     = 0;
      while (x != 320) {
        int12  y_ground = uninitialized;
        int12  y_screen = uninitialized;
        int11  y        = uninitialized;
        int9   delta_y  = uninitialized;
        int24  hmap     = uninitialized;
        uint10 v_interp = uninitialized;
        // get elevation from interpolator
        hmap           = interp_v;
        // apply perspective to obtain y_ground on screen
        y_ground       = (((vheight + 50 - hmap) * inv_z) >>> $fp-4$) + 8;
        // retrieve last altitude at this column, if first reset to 199
        y_last.wenable = (iz == 0);
        y_last.wdata   = 199;
++: // wait for y_last to be updated
        // restart drawing from last one (or 199 if first)
        y              = (iz == 0) ? 199 : y_last.rdata;
        // prepare vertical interpolation factor (color dithering)
        delta_y        = (y - y_ground); // y gap that will be drawn
        // NOTE: this is not correct around silouhettes, but visually
        //       did not seem to produce artifacts, so keep it simple!
        inv_n.addr     = delta_y;        // one over the gap size
        v_interp       = 0;              // interpolator accumulation
        // clamp on screen
        y_screen       = (iz == $z_num_step-1$) ? 0 : (((y_ground < 0) ? 0 : ((y_ground > 199) ? 199 : y_ground)));
        //                ^^^^^^^^^^^^^^^^^^^^^^^^^ draw sky on last
        // fill column
        while (y >= y_screen) { // geq is needed as y_screen might be 'above' (below on screen)
          // color dithering
          uint4 clr(0); uint1 l_or_r(0); uint1 t_or_b(0);          
          l_or_r = bayer_8x8[ { y[0,3] , x[0,3] } ] > l_x     [$fp-6$,6];
          t_or_b = bayer_8x8[ { x[0,3] , y[0,3] } ] > v_interp[4,6];
          clr    = l_or_r ? ( t_or_b ? h00[8,4] : h01[8,4] ) : (t_or_b ? h10[8,4] : h11[8,4]);          
          // clr        = h00[8,4];      // uncomment to visualize nearest mode
          // clr        = l_x[$fp-4$,4]; // uncomment to visualize u interpolator
          // clr        = v_interp[6,4]; // uncomment to visualize v interpolator
          // update v interpolator
          v_interp    = v_interp + inv_n.rdata;
          // write to framebuffer
          fb.rw       = 1;
          fb.data_in  = (iz == $z_num_step-1$) ? $sky_pal_id$ : ((clr) << ({x[0,2],2b0}));
          //             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ draw sky on last
          fb.wmask    = 1 << x[0,2];
          fb.in_valid = 1;
          fb.addr     = (x >> 2) + (y << 6) + (y << 4);  //  320 x 200, 4bpp    x>>2 + y*80          
          y           = y - 1;
        }
        // write current altitude for next
        y_last.wenable = 1;
        y_last.wdata   = (y_screen[0,8] < y_last.rdata) ? y_screen[0,8] : y_last.rdata;
        // update position
        x   =   x +  1;
        l_x = l_x + dx;
        // sample next elevations
        {
          uint8  hv0(0); uint8  hv1(0);
          // texture interpolation  
          // interleaves access and interpolator computations
          map0_raddr = {l_y[$fp$,7],l_x[$fp$,7]};
++:          
          h00        = map0_rdata;
          map0_raddr = {l_y[$fp$,7],l_x[$fp$,7]+7b1};
++:          
          h10        = map0_rdata;
          interp_a   = h00[0,8];  // first interpolation
          interp_b   = h10[0,8];
          interp_i   = l_x[$fp-8$,8];
          map0_raddr = {l_y[$fp$,7]+7b1,l_x[$fp$,7]+7b1};
++:       
           hv0        = interp_v;
           h11        = map0_rdata;
           map0_raddr = {l_y[$fp$,7]+7b1,l_x[$fp$,7]};
 ++:          
           h01        = map0_rdata;
// NOTE: we don't need to interpolate height along the second line
//       this would become necessary with partial advance or free rotation
//           interp_a   = h01[0,8]; // second interpolation
//           interp_b   = h11[0,8];
// ++:
//           hv1        = interp_v;
//           interp_a   = hv0;      // third interpolation
//           interp_b   = hv1;
//           interp_i   = l_y[$fp-8$,8];
        }
      }      
      z  = z + $z_step$;
      iz = iz + 1;
    }
    fbuffer = ~fbuffer;
$$if NUM_BTNS then 
    // use buttons   
    switch (r_btns) {
      case 1: { v_x   = v_x - $fp_scl//2$; }
      case 2: { v_x   = v_x + $fp_scl//2$; }
      case 4: { v_y   = v_y + $fp_scl$;    }
    }
$$else
    // auto advance
    v_y   = v_y + $fp_scl$;
$$end    
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

  // ==== voxel space renderer instantiation
  // interface for GPU writes in framebuffer
  fb_r16_w16_io fb;
  uint1 fbuffer(0); // frame bnuffer selected for display (writes can occur in ~fbuffer)  
  vxlspc vs(
    fb          <:> fb,
    fbuffer      :> fbuffer,
    btns         <: btns,
    map0_raddr   :> map0_raddr,
    map0_rdata   <: map0_data_out,
    map1_raddr   :> map1_raddr,
    map1_rdata   <: map1_data_out,
  );

  bram uint24 palette[16] = {
$$for i=1,16 do
//      $(i-1)*16$,
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

  // leds           := {4b0,fbuffer};

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
              leds = mem.data_in[0,8];
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
