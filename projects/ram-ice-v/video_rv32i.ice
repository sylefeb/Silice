// SL 2020-12-02 @sylefeb
// ------------------------- 
$$if SIMULATION then
$$ verbose = nil
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
$include('sdram_ram_32bits.ice')
$include('basic_cache_ram_32bits.ice')

// ------------------------- 

algorithm frame_drawer(
  sdram_user    sd,
  sdram_user    sda,
  input  uint1  sdram_clock,
  input  uint1  sdram_reset,
  input  uint1  vsync,
  input  uint1  data_ready,
  output uint1  fbuffer = 0,
  simple_dualport_bram_port1 palette,
) <autorun> {

  rv32i_ram_io sdram;

  uint26 predicted_addr    = uninitialized;
  uint1  predicted_correct = uninitialized;
  uint32 data_override(0);

  // sdram io
  sdram_ram_32bits bridge<@sdram_clock,!sdram_reset>(
    sdr <:> sd,
    r32 <:> sdram,
  );

  // basic cache  
  rv32i_ram_io cram;
  uint26 cache_start = 26h2000000;  

  basic_cache_ram_32bits cache(
    pram              <:> cram,
    uram              <:> sdram,
    cache_start       <:  cache_start,
    predicted_addr    <:  predicted_addr,
    predicted_correct <:  predicted_correct,
    data_override     <:  data_override
  );

  uint26 cpu_start_addr(26h2000000);
  uint3  cpu_id(0);
  uint1  cpu_reset(1);

  // cpu 
  rv32i_cpu cpu<!cpu_reset>(
    boot_at           <:  cpu_start_addr,
    predicted_addr    :>  predicted_addr,
    predicted_correct :>  predicted_correct,
    cpu_id            <:  cpu_id,
    ram               <:> cram
  );

  fbuffer          := 0;

  while (1) {

    cpu_reset = ~data_ready;

    if (cram.in_valid & cram.addr[30,1]) {
      __display("palette %h = %h",cram.addr[2,8],cram.data_in[0,24]);
      palette.addr1    = cram.addr[2,8];
      palette.wdata1   = cram.data_in[0,24];
      palette.wenable1 = 1;
    }

  }
}

// ------------------------- 
