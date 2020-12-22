// SL 2020-12-02 @sylefeb
// ------------------------- 

// pre-compilation script, embeds compile code within sdcard image
$$dofile('pre_include_asm.lua')

// basic palette
$$palette = {}
$$for i=1,256 do
$$  palette[i] = (i) | (((i<<1)&255)<<8) | (((i<<2)&255)<<16)
$$end
$$ palette[256] = 255 | (255<<8) | (255<<16)

$include('../common/video_sdram_main.ice')

$$SHOW_REGS = false

$include('ram-ice-v.ice')
$include('sdram_ram_32bits.ice')
$include('basic_cache_ram_32bits.ice')

$$Nway = 2
$include('../common/sdram_arbitrers.ice')

// ------------------------- 

algorithm frame_drawer(
  sdram_user    sd,
  input  uint1  sdram_clock,
  input  uint1  sdram_reset,
  input  uint1  vsync,
  output uint1  fbuffer,
  output uint4  audio_l,
  output uint4  audio_r,
) <autorun> {

  sameas(sd) sdh;
  sdram_half_speed_access sdram_slower<@sdram_clock,!sdram_reset>(
    sd  <:> sd,
    sdh <:> sdh
  );

  sameas(sd) sd0;
  sameas(sd) sd1;
  sdram_arbitrer_2way arbitrer(
    sd  <:> sdh,
    sd0 <:> sd0,
    sd1 <:> sd1,
  );

  rv32i_ram_io ram0;
  rv32i_ram_io ram1;

  // sdram io
  sdram_ram_32bits bridge0(
    sdr <:> sd0,
    r32 <:> ram0,
  );
  sdram_ram_32bits bridge1(
    sdr <:> sd1,
    r32 <:> ram1,
  );

  // basic cache  
  uint26 cache0_start = 26h2000000;
  uint26 cache1_start = 26h2010000;
  rv32i_ram_io cram0;
  rv32i_ram_io cram1;  
  basic_cache_ram_32bits cache0(
    pram <:> cram0,
    uram <:> ram0,
    cache_start <: cache0_start,
  );
  basic_cache_ram_32bits cache1(
    pram <:> cram1,
    uram <:> ram1,
    cache_start <: cache1_start,
  );

  uint1  cpu0_enable     = 0;
  uint1  cpu1_enable     = 0;
  uint26 cpu0_start_addr = 26h2000000;
  uint26 cpu1_start_addr = 26h2010000;

  // cpu0
  uint3 cpu0_id = 0;
  rv32i_cpu cpu0(
    enable   <:  cpu0_enable,
    boot_at  <:  cpu0_start_addr,
    cpu_id   <:  cpu0_id,
    ram      <:> cram0
  );
  // cpu1
  uint3 cpu1_id = 1;
  rv32i_cpu cpu1(
    enable   <:  cpu1_enable,
    boot_at  <:  cpu1_start_addr,
    cpu_id   <:  cpu1_id,
    ram      <:> cram1
  );

  uint1  vsync_filtered = 0;
  
  vsync_filtered ::= vsync;
  fbuffer        := 0;

  always {  
    cpu0_enable = 1;
    cpu1_enable = 1;

    if (ram0.in_valid && ram0.rw && ram0.addr[26,2] == 2b11) {
      __display("audio 0, %h",ram0.data_in[0,8]);
      audio_l = ram0.data_in[0,4];
    }
    if (ram1.in_valid && ram1.rw && ram1.addr[26,2] == 2b11) {
      __display("audio 1, %h",ram1.data_in[0,8]);
      audio_r = ram1.data_in[0,4];
    }

  }

}

// ------------------------- 
