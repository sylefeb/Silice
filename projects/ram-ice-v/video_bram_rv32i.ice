// SL 2020-12-02 @sylefeb
// ------------------------- 

$$if SIMULATION then
$$verbose = nil
$$end

// pre-compilation script, embeds compile code within sdcard image
$$dofile('pre_include_asm.lua')
$$if not SIMULATION then
$$  init_data_bytes = math.max(init_data_bytes,(1<<21)) -- we load 2 MB to be sure we can append stuff
$$end

// default palette
$$palette = {}
$$for i=1,256 do
$$  palette[i] = (i) | (((i<<1)&255)<<8) | (((i<<2)&255)<<16)
$$end
$$ palette[256] = 255 | (255<<8) | (255<<16)

$$if SIMULATION then
$$  frame_drawer_at_sdram_speed = true
$$else
$$  fast_compute = true
$$end

$include('../common/video_sdram_main.ice')

$include('ram-ice-v.ice')
$include('bram_ram_32bits.ice')
$include('sdram_ram_32bits.ice')

// ------------------------- 

$$div_width=24
$include('../common/divint_std.ice')

algorithm edge_intersect(
  input  uint16  y,
  input  uint16 x0, // 10+6 fixed point
  input  uint16 y0,
  input  uint16 x1,
  input  uint16 y1,
  output uint16 xi,
  output uint1  intersects
) <autorun> {
  div24 div;

  uint1  in_edge ::= (y0 < y && y1 >= y) || (y1 < y && y0 >= y);
  uint14 interp    = uninitialized;

  intersects := in_edge;
  while (1) {
    if (in_edge) {
__display("start %d %d %d %d -- %d",x0>>6,y0>>6,x1>>6,y1>>6,y>>6);
      (interp) <- div <- ((x1-x0)<<8,(y-y0)>>6);
      xi = x0 + ((interp * (x1-x0)) >> 14);
__display("  result : %b %d",intersects,xi>>6);
    }
  }
}

// ------------------------- 

algorithm frame_drawer(
  sdram_user    sd,
  input  uint1  sdram_clock,
  input  uint1  sdram_reset,
  input  uint1  vsync,
  output uint1  fbuffer,
  output uint8  leds,
  simple_dualport_bram_port1 palette,
) <autorun> {

  rv32i_ram_io sdram;
  // sdram io
  sdram_ram_32bits bridge<@sdram_clock,!sdram_reset>(
    sdr <:> sd,
    r32 <:> sdram,
  );

  rv32i_ram_io mem;
  uint26 predicted_addr = uninitialized;

  // bram io
  bram_ram_32bits bram_ram(
    pram <:> mem,
    predicted_addr <: predicted_addr,
  );

  uint1  cpu_reset      = 1;
  uint26 cpu_start_addr = 26h0000000;
  uint3  cpu_id         = 0;
  
  // cpu 
  rv32i_cpu cpu<!cpu_reset>(
    boot_at  <:  cpu_start_addr,
    predicted_addr :> predicted_addr,
    cpu_id   <:  cpu_id,
    ram      <:> mem
  );

  // fun
  uint16  y  = uninitialized;
  uint16  x0 = uninitialized; // 10+6 fixed point
  uint16  y0 = uninitialized;
  uint16  x1 = uninitialized;
  uint16  y1 = uninitialized;
  int16   xi = uninitialized;
  uint1   intersects = uninitialized;
  edge_intersect ei(<:auto:>);

  fbuffer              := 0;
  sdram.rw             := 0;
  palette.wenable1     := 0;
  sdram.in_valid       := 0;

  while (1) {
    cpu_reset = 0;

    if (mem.in_valid & mem.rw) {
      switch (mem.addr[28,4]) {
        case 4b1000: {
          // __display("palette %h = %h",mem.addr[2,8],mem.data_in[0,24]);
          palette.addr1    = mem.addr[2,8];
          palette.wdata1   = mem.data_in[0,24];
          palette.wenable1 = 1;
        }
        case 4b0100: {
          // __display("SDRAM %h = %h",mem.addr[0,26],mem.data_in);
          sdram.data_in  = mem.data_in;
          sdram.wmask    = mem.wmask;
          sdram.addr     = mem.addr[0,26];
          sdram.rw       = 1;
          sdram.in_valid = 1;
        }
        case 4b0010: {
          __display("LEDs = %h",mem.data_in[0,8]);
          leds = mem.data_in[0,8];
        }
        case 4b0001: {
          // __display("triangle (%b) = %d %d",mem.addr[2,3],mem.data_in[0,16]>>6,mem.data_in[16,16]>>6);
          switch (mem.addr[2,3]) {
            case 3b001: { x0 = mem.data_in[0,16]; y0 = mem.data_in[16,16]; }
            case 3b010: { x1 = mem.data_in[0,16]; y1 = mem.data_in[16,16]; }
            case 3b100: { y  = mem.data_in[0,16]; }
            default: { }
          }
        }
        default: { }
      }
    }
    
  }
}

// ------------------------- 
