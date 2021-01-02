// SL 2020-12-02 @sylefeb
// ------------------------- 

// pre-compilation script, embeds compile code within sdcard image
$$dofile('pre_include_asm.lua')
$$if not SIMULATION then
$$  init_data_bytes = math.max(init_data_bytes,(1<<21)) -- we load 2 MB to be sure we can append stuff
$$end

$include('../common/video_sdram_main.ice')

// default palette
$$palette = {}
$$for i=1,256 do
$$  palette[i] = (i) | (((i<<1)&255)<<8) | (((i<<2)&255)<<16)
$$end
$$ palette[256] = 255 | (255<<8) | (255<<16)

$include('ram-ice-v.ice')
$include('sdram_ram_32bits.ice')
$include('basic_cache_ram_32bits.ice')

// ------------------------- 

algorithm frame_drawer(
  sdram_user    sd,
  input  uint1  sdram_clock,
  input  uint1  sdram_reset,
  input  uint1  vsync,
  output uint1  fbuffer,
  simple_dualport_bram_port1 palette,
) <autorun> {

  sameas(sd) sdh;
  sdram_half_speed_access sdram_slower<@sdram_clock,!sdram_reset>(
    sd  <:> sd,
    sdh <:> sdh
  );

  rv32i_ram_io ram;

  // sdram io
  sdram_ram_32bits bridge(
    sdr <:> sdh,
    r32 <:> ram,
  );

  // basic cache  
  rv32i_ram_io cram;
  uint26 cache_start = 26h2000000;
  
  basic_cache_ram_32bits cache(
    pram <:> cram,
    uram <:> ram,
    cache_start <: cache_start,
  );

  uint1  cpu_enable     = 0;
  uint26 cpu_start_addr = 26h2000000;
  uint3  cpu_id         = 0;

  // cpu 
  rv32i_cpu cpu(
    enable   <:  cpu_enable,
    boot_at  <:  cpu_start_addr,
    cpu_id   <:  cpu_id,
    ram      <:> cram
  );

  fbuffer          := 0;

  always {
  
    cpu_enable      = 1;

    if (cram.in_valid & cram.rw & cram.addr[31,1]) {
      __display("palette %h = %h",cram.addr[2,8],cram.data_in[0,24]);
      palette.addr1    = cram.addr[2,8];
      palette.wdata1   = cram.data_in[0,24];
      palette.wenable1 = 1;
    }

  }
}

// ------------------------- 
