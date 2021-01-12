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
/*
$$div_width=16
include('../common/divint_std.ice')

algorithm edge_intersect(
  input  uint9  y,
  input  uint16 x0, // 9+7 fixed point
  input  uint16 y0,
  input  uint16 x1,
  input  uint16 y1,
  output uint16 xi,
  output uint1  intersects
) {

  uint1 in_edge ::= (y0 < y && y1 >= y) || (y1 < y && y0 >= y);

  if (in_edge) {
    () <- 
  }
}
*/
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
  uint2        sdram_pulse_in_valid(2b00);
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

  fbuffer              := 0;
  sdram.rw             := 0;
  palette.wenable1     := 0;
  sdram_pulse_in_valid := {1b0,sdram_pulse_in_valid[1,1]};
$$if SIMULATION then  
  sdram.in_valid       := 0;
$$else
  sdram.in_valid       := 0;
//  sdram.in_valid       := sdram_pulse_in_valid[0,1];
$$end

  while (1) {

    cpu_reset = 0;

    if (mem.in_valid & mem.rw) {
      switch (mem.addr[29,3]) {
        case 3b100: {
          // __display("palette %h = %h",mem.addr[2,8],mem.data_in[0,24]);
          palette.addr1    = mem.addr[2,8];
          palette.wdata1   = mem.data_in[0,24];
          palette.wenable1 = 1;
        }
        case 3b010: {
          // __display("SDRAM %h = %h",mem.addr[0,26],mem.data_in);
          sdram.data_in  = mem.data_in;
          sdram.wmask    = mem.wmask;
          sdram.addr     = mem.addr[0,26];
          sdram.rw       = 1;
$$if SIMULATION then  
          sdram.in_valid = 1;
$$end
          sdram.in_valid = 1;
//          sdram_pulse_in_valid = 2b11;
        }
        case 3b001: {
          __display("LEDs = %h",mem.data_in[0,8]);
          leds = mem.data_in[0,8];
        }
        default: { }
      }
    }
    
  }
}

// ------------------------- 
