### Assembling the framework: Code walkthrough

Here is a walkthrough of the Silice code assembling this design within the framework.

The algorithm to implement when using the framework is `frame_drawer`, with the following signature:

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

The first line is the SDRAM interface that we will use to read/write from the main memory. `sdram_clock` and `sdram_reset` and respectively the SDRAM clock (100 MHz) and reset signal. Next, we can output a single bit `fbuffer` value, which selects the framebuffer currently shown on screen (we use double-buffering). In this project, we never swap and always draw to the visible framebuffer -- expect some flickering!
Finally, `audio_l` and `audio_r` are the audio pins. For more details on audio please refer to the [streaming audio project](../audio_sdcard_streamer/).

We will now add components to our design. Note that these correspond to files included at the top:
```c
$include('../common/video_sdram_main.ice')
$include('../common/audio_pwm.ice')
$$Nway = 2
$include('../common/sdram_arbitrers.ice')
$include('ram-ice-v.ice')
$include('sdram_ram_32bits.ice')
$include('basic_cache_ram_32bits.ice')
```

First, we use a special adapter to lower the frequency at which we talk to the SDRAM. It runs at 100MHz in the framework, while our CPUs will run at 50MHz.

```c
  sameas(sd) sdh;
  sdram_half_speed_access sdram_slower<@sdram_clock,!sdram_reset>(
    sd  <:> sd,
    sdh <:> sdh
  );
```

Notice the `<@CLOCK,!RESET>` that allows to specify a clock and reset signal different from the host algorithm.

As we have two CPUs sharing memory, we need an arbiter:

```c
  sameas(sd) sd0;
  sameas(sd) sd1;
  sdram_arbitrer_2way arbitrer(
    sd  <:> sdh,
    sd0 <:> sd0,
    sd1 <:> sd1,
  );
```

This particular arbiter gives a higher priority to 0 versus 1. In this case, an equal priority would be even better, but let's reuse what we already have! Now we have split our main SDRAM interface `sdh` into two SDRAM interfaces `sd0` and `sd1`.

Due to the SDRAM interface being 128 bits for reads and 8 bits for write, we need an adapter to make it more friendly to 32 bits CPUs (and yes, this comes at a huge cost in latency and cycles, to be improved!). This is done for each interface:

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

We know have two 32-bits memory interfaces, one for each CPUs. Almost there, but first let's add the instruction caches:

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

Note the start addresses specified for the caches. They only cover some number of addresses from this initial location (size configured in [basic_cache_ram_32bits.ice](basic_cache_ram_32bits.ice)).

And now let's create our two RV32I CPUs!

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

Note the boot addresses being specified.

Finally, to obtain reasonable audio from the 4-bits DAC, we create the PWMs, one for each left/right channel.

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

We are ready to write some code ... but in fact not much since the CPUs will do everything from their own programs. First, we fix the framebuffer (at startup, zero is the one show on screen):

```c
  fbuffer        := 0;
```
The `:=` syntax means `fbuffer` is always set to this value, at every cycle.

And finally the main program:

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
This algorithm uses only an `always` loop, executed at every clock cycle. It does only two things. First, it tells the CPUs to run by setting `cpu0_enable` and `cpu1_enable`. Second, it performs some memory mapping for the audio, inspecting the ongoing read/writes and intercepting specific addresses.

This is it!
