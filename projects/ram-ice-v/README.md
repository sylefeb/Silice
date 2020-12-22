# RISC-V on top of SDRAM with graphics, sound and sdcard.

The purpose of this project is to demonstrate how the various demo components coming with Silice can be composed into a full fledged small computer (with multiple CPUs!).

The two main designs are:
- [video_rv32i.ice](video_rv32i.ice): a single processor design.
- [video_dual_rv32i.ice](video_dual_rv32i.ice): a dual processor design with audio.

This comes with a minimalist (and quite horrible) 'libc' providing the basics such as printf and a few low level functions. 

**Still Learning** I am absolutely not a CPU design expert, I am just learning, playing and sharing :) There is surely much to improve here.Please let me know your thoughts!

**Note** This is still work in progress, this documentation will improve in the coming days.

## Build and run!

**TODO**

## Overall architecture

We rely on the graphics framework, primarily defined in
[../common/video_sdram_main.ice](../common/video_sdram_main.ice)
and [../common/video_sdram.ice](../common/video_sdram.ice). It essentially implements a framebuffer in SDRAM, with the possibility to load data from an sdcard at startup.

The graphics framework is targeting boards with HDMI/VGA and SDRAM. This is typically the ULX3S or the de10nano with a [MiSTer](https://github.com/MiSTer-devel/Main_MiSTer/wiki) setup.

*Note*: This project has been only tested with the ULX3S thus far.

### Architecture diagram

Here is a diagram of the architecture with the main modules. 

**TODO**

The CPUs run at 50 MHz, while the external SDRAM interface runs at 100MHz and the HDMI controller at 125MHz. 

### Using the framework with RISC-V: Code walkthrough

Here is a walkthrough the Silice code assembling this design within the framework.

The algorithm to implement when using the framework is `framedrawer`, with the following signature:

```c
algorithm frame_drawer(
  sdram_user    sd,
  input  uint1  sdram_clock,
  input  uint1  sdram_reset,
  input  uint1  vsync,
  output uint1  fbuffer,
  output uint4  audio_l,
  output uint4  audio_r,
) <autorun> {
```

The first line is the SDRAM interface that we will use to read/write from the main memory.
`sdram_clock` and `sdram_reset` and respectively the SDRAM clock (100 MHz) and reset signal.
Next, we can output a single bit `fbuffer` value, which selects the framebuffer currently
shown on screen (we use double-buffering). In this project, we never swap and always draw to the 
visible framebuffer -- expect some flickering!
Next, `audio_l` and `audio_r` are the audio pins. For more details on audio please refer to
the (streaming audio project)[../audio_sdcard_streamer/].

First, we use a special adapter to lower the frequency at which we talk to the SDRAM. It runs
at 100MHz in the framework, while our CPUs will run at 50MHz.

```c
  sameas(sd) sdh;
  sdram_half_speed_access sdram_slower<@sdram_clock,!sdram_reset>(
    sd  <:> sd,
    sdh <:> sdh
  );
```

```c
  sameas(sd) sd0;
  sameas(sd) sd1;
  sdram_arbitrer_2way arbitrer(
    sd  <:> sdh,
    sd0 <:> sd0,
    sd1 <:> sd1,
  );
```

```c
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
```

```c
  // basic instruction caches
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
```

```c
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
```

```c
  // audio pwms
  uint8 wave_l = uninitialized;
  audio_pwm left(
    wave  <: wave_l,
    audio :> audio_l,
  );
  uint8 wave_r = uninitialized;
  audio_pwm right(
    wave  <: wave_r,
    audio :> audio_r,
  );
```

```c
  fbuffer        := 0;
```

```c
  always {  
    cpu0_enable = 1;
    cpu1_enable = 1;
    if (ram0.in_valid && ram0.rw && ram0.addr[26,2] == 2b11) {
      __display("audio 0, %h",ram0.data_in[0,8]);
      wave_l = ram0.data_in[0,8];
    }
    if (ram1.in_valid && ram1.rw && ram1.addr[26,2] == 2b11) {
      __display("audio 1, %h",ram1.data_in[0,8]);
      wave_r = ram1.data_in[0,8];
    }
  }
}
```


## The SDRAM controller and arbitrer


## The instruction 'cache'

The core issue with fitting the design in a full framework built around SDRAM is that
the bandwidth is shared, and somewhat pressured by the framebuffer. This is particularly
a problem when fetching instructions, as each could take many cycles (10+) to become available. To mitigate this, I created a small component, (basic_cache_ram_32bits.ice)[basic_cache_ram_32bits.ice] which sits between the CPU and the SDRAM interface. It implements a naive cache mechanism where read and writes are remembered in a memory space covering the program instructions and stack. Good out of the cached space is safe, but slow. 

The cache relies on simple dualport BRAMs to allow for the cache content to be updated, while starting to fetch the next instruction, which we know is very likely to be the one required. This, together with the CPU design itself, allows to process instructions in as little as two cycles.

## The RiscV processor

This is a RV32I design. It has no fancy features, and is meant to remain simple
and easy to modify / hack. Its most 'advanced' feature is that it tries to 
optimistically fetch the next instruction before being done with the current one.
Together with the instruction cache, this allows many instructions to execute in
only 2 cycles. 

The design is not optimized for compactness, for that please checkout the (ice-v)[../projects/ice-v] which implements an RV32I fitting on an IceStick! (~1182 LUTs with OLED
controller).


## Links
- Demo project voices made with https://text-to-speech-demo.ng.bluemix.net/
