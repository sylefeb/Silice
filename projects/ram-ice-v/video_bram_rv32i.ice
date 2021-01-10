// SL 2020-12-02 @sylefeb
// ------------------------- 

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

$$frame_drawer_at_sdram_speed = true
$include('../common/video_sdram_main.ice')

$$SHOW_REGS = true

$include('ram-ice-v.ice')
$include('bram_ram_32bits.ice')
$include('sdram_ram_32bits.ice')

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
  sdram_ram_32bits bridge(
    sdr <:> sd,
    r32 <:> sdram,
  );

  rv32i_ram_io mem;

  // bram io
  bram_ram_32bits bram_ram(
    pram <:> mem,
  );

  uint1  cpu_reset      = 1;
  uint26 cpu_start_addr = 26h0000000;
  uint3  cpu_id         = 0;
  
  uint1  sdram_done_pulsed = 0;

  // cpu 
  rv32i_cpu cpu(
    boot_at  <:  cpu_start_addr,
    cpu_id   <:  cpu_id,
    ram      <:> mem
  );

  fbuffer          := 0;
  sdram.in_valid   := 0;
  sdram.rw         := 0;
  palette.wenable1 := 0;
  
  while (1) {

    cpu_reset = 0;

    if (mem.in_valid & mem.rw & mem.addr[31,1]) {
      //__display("palette %h = %h",mem.addr[2,8],mem.data_in[0,24]);
      palette.addr1    = mem.addr[2,8];
      palette.wdata1   = mem.data_in[0,24];
      palette.wenable1 = 1;
    }

    if (mem.in_valid & mem.rw & mem.addr[30,1]) {
      //__display("SDRAM %h = %h",mem.addr[0,26],mem.data_in);
      sdram.data_in  = mem.data_in;
      sdram.wmask    = mem.wmask;
      sdram.addr     = mem.addr[0,26];
      sdram.rw       = 1;
      sdram.in_valid = 1;
    }

    if (mem.in_valid & mem.rw & mem.addr[29,1]) {
      //__display("LEDs = %h",mem.data_in[0,8]);
      leds = mem.data_in[0,8];
    }

  }
}

// ------------------------- 
