// SL 2020-12-02 @sylefeb
//
// Wildfire --- Risc-V framework in Silice, with:
//  - pipelined SDRAM
//  - fast code memory (from 26h2000000 to BRAM size)
//  - hardware accelerated triangle rasterizer (why not?)
//  - overclocks up to 160 MHz on the ULX3S
// 
// Test on: ULX3S, Verilator, Icarus
//
// ------------------------- 

$$if SIMULATION then
$$ verbose = nil
$$end

$$if not (ULX3S or ICARUS or VERILATOR) then
$$error('Sorry, Wildfire is currently not supported on this board.')
$$end

// pre-compilation script, embeds compile code within sdcard image
$$dofile('pre/pre_include_asm.lua')
$$code_size_bytes = init_data_bytes

$$init_data_bytes = nil

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

$$if SIMULATION then
$$  frame_drawer_at_sdram_speed = true
$$else
$$  fast_compute = true
$$end

$$mode_640_480   = true
$$SDRAM_r512_w64 = true

$include('../common/video_sdram_main.ice')

$include('fire-v/fire-v.ice')
$include('ash/sdram_ram_32bits.ice')
$include('ash/bram_segment_ram_32bits.ice')
$include('flame/flame.ice')

// ------------------------- 

algorithm frame_drawer(
  sdram_user    sd,  // main
  sdram_user    sda, // aux
  input  uint1  sdram_clock,
  input  uint1  sdram_reset,
  input  uint1  vsync,
  output uint1  fbuffer = 0,
  output uint8  leds,
$$if SDCARD then  
  output uint1  sd_clk,
  output uint1  sd_mosi,
  output uint1  sd_csn,
  input  uint1  sd_miso,
$$end  
  simple_dualport_bram_port1 palette,
) <autorun> {

  rv32i_ram_io sdram;
  // sdram io
  sdram_ram_32bits bridge<@sdram_clock,!sdram_reset>(
    sdr <::> sda,
    r32 <::> sdram,
  );

  uint26 predicted_addr    = uninitialized;
  uint1  predicted_correct = uninitialized;

  // basic cache  
  rv32i_ram_io mem;
  uint26 cache_start = 26h2000000;
  bram_segment_ram_32bits cache(
    pram              <:> mem,
    uram              <:> sdram,
    cache_start       <:  cache_start,
    predicted_addr    <:  predicted_addr,
    predicted_correct <:  predicted_correct,
  );

  uint1  cpu_reset      = 1;
  uint26 cpu_start_addr(26h2000000);
  uint32 user_data(0);

  // cpu 
  rv32i_cpu cpu<!cpu_reset>(
    boot_at           <:  cpu_start_addr,
    predicted_addr    :>  predicted_addr,
    predicted_correct :>  predicted_correct,
    user_data         <:  user_data,
    ram               <:> mem
  );

  // sdcard
  uint1  reg_miso(0);

$$if SIMULATION then
   uint24 cycle = 0;
$$end

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

  triangle_in      := 0;

  while (1) {

    cpu_reset = 0;
$$if SDCARD then    
    user_data = {{28{1b0}},reg_miso,1b0,vsync,drawing};
    reg_miso  = sd_miso;
$$else    
    user_data = {{28{1b0}},1b0,1b0,vsync,drawing};
$$end

    if (mem.in_valid & mem.rw) {
      switch (mem.addr[27,4]) {
        case 4b1000: {
          // __display("palette %h = %h",mem.addr[2,8],mem.data_in[0,24]);
          palette.addr1    = mem.addr[2,8];
          palette.wdata1   = mem.data_in[0,24];
          palette.wenable1 = 1;
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
$$if SDCARD then    
            case 2b10: {
              // SDCARD
              __display("SDCARD %b",mem.data_in[0,3]);
              sd_clk  = mem.data_in[0,1];
              sd_mosi = mem.data_in[1,1];
              sd_csn  = mem.data_in[2,1];
            }           
$$end            
            default: { }
          }
        }
        case 4b0001: {
//          __display("(cycle %d) triangle (%b) = %d %d",cycle,mem.addr[2,5],mem.data_in[0,16],mem.data_in[16,16]);
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
//                               __display("new triangle (color %d), cycle %d, %d,%d %d,%d %d,%d",color,cycle,x0,y0,x1,y1,x2,y2);
$$end                               
                              }
            default: { }
          }
        }
        default: { }
      }
    }

$$if SIMULATION then
    cycle = cycle + 1;
$$end    

  }
}

// ------------------------- 
