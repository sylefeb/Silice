# Silice RISC-V framework with SDRAM, graphics, audio, sdcard and multiple CPUs

The purpose of this project is to demonstrate how the various demo components coming with Silice can be composed into a full fledged small computer (with multiple CPUs!).

The two main designs are:
- [video_rv32i.ice](video_rv32i.ice): a single processor design.
- [video_dual_rv32i.ice](video_dual_rv32i.ice): a dual processor design with audio.

This comes with a minimalist (and quite horrible) 'libc' providing the basics such as printf and a few low level functions. And yes, *you compile code for these CPUs directly from gcc*, one of the many things that makes RISC-V great!

**Note:** I am absolutely not a CPU design expert, I am just learning, playing and sharing :) There is surely much to improve here. Please let me know your thoughts!

**Note:** This is still work in progress, this documentation will improve in the coming days.

## Build and run!

If you have never used Silice before, see [getting started](../../GetStarted.md) for initial setup (Windows, Linux, MacOS).

### The dual CPU demo (has sound)

Plug your board, open a command line in this folder and run:
```
./compile_dual_demo.sh
```
The board is programmed, but you also have to write the (just produced) file `sdcard.img` on an sdcard and insert the sdcard in the board. On the ULX3S press 'PWR' to reset. Please use a SDHC card.

**Important:** The sdcard image has to be written raw, for instance using `Win32DiskImager` on Windows. Beware that all previous data will be lost.

**Known issues:** 
- The sdcard sometimes fails to initialize. If this happens, try a reset (press 'PWR'). Next, try to carefully remove and re-insert the card after 1-2 seconds. Another option is to flash the board with `fujprog -j flash BUILD_ulx3s/built.bin`, usually the sdcard works fine on power up.
- If you update the sdcard image, reset won't reload it properly, you'll have to power cycle the board (or reprogram it). Fixing this asap!

### Your own code

If you write code in a file `tests/c/mycode.c` you can then produce the sdcard image as follows:
```
./compile_dual.sh tests/c/mycode.c
make sdcard
```

### Dhrystone

Plug your board, open a command line in this folder and run:
```
./compile_dhrystone.sh
make ulx3s
```
The board is programmed, but you also have to write the (just produced) file `data.img` on an sdcard and insert the sdcard in the board. On the ULX3S press 'PWR' to reset.

This also runs in simulation:
```
./compile_dhrystone.sh
make verilator
```
See images output in `BUILD_verilator/`.

If I got this right, the CPU currently gets a score of 4.975 cycles per instruction with video active and a 16KB cache (configured in [basic_cache_ram_32bits](basic_cache_ram_32bits.ice)).

## Overall architecture

I rely on the Silice graphics framework (the same one [used by the Doom-chip](../doomchip/)), primarily defined in [video_sdram_main.ice](../common/video_sdram_main.ice) and [video_sdram.ice](../common/video_sdram.ice). It essentially implements a 320x200 8-bit palette framebuffer in SDRAM, with the possibility to load data from an sdcard at startup.

The graphics framework is targeting boards with HDMI/VGA and SDRAM. This is typically the ULX3S or the de10nano with a [MiSTer](https://github.com/MiSTer-devel/Main_MiSTer/wiki) setup.

**Note:** This project has been only tested with the ULX3S thus far.

### Memory space

The ways SDRAM is split is interesting. My approach to this is to not worry about wasting memory -- I mean, 32 MB is huge, right?

Memory addresses are 26 bits, with the two highest bits indicated the memory banks. We have the following organization:
- **Bank 0** [0x0000000 - 0x0ffffff] Framebuffer 0
- **Bank 1** [0x1000000 - 0x1ffffff] Framebuffer 1
- **Bank 2** [0x2000000 - 0x2ffffff] Data loaded from sdcard at startup.
- **Bank 3** [0x3000000 - 0x3ffffff] Free!

The framebuffers occupy addresses up to 18fff in their banks. This might seem surprising: a frame is 320x200 so one would expect f9ff. Well, this is because the rows of 320 pixels are stored apart from each other, with a total spacing of 512 bytes. This allows a pixel address to be computed as `x + y<<9`. But you are free to  squeeze other data in the `512-320` unused space, the framebuffer does not touch it.

Where will the CPU code endup? This is specified in `config_cpu0.ld` and `config_cpu1.ld`. The first uses addresses from 0x2000000, the second from 0x2010000. So of course this is assuming this leaves enough space for code ... and stack! The code is shifted by 512 bytes so the stack starts at 0x20001ff and 0x20101ff (it grows downwards). See `crt0.s`. This shift is there to simplify the cache that covers both the instructions and the stack.

### Architecture diagram

Here is a diagram of the architecture with the main modules. 

<img src="architecture.png">

The CPUs run at 50 MHz, while the external SDRAM interface runs at 100MHz and the HDMI controller at 125MHz.  Let us discuss a few components.

The reason for the 128 burst reads in the main SDRAM controller is to allow for higher efficiency when the framebuffer memory is read during screen refresh. The 8-bit write makes it simpler to write data for individual pixels in the framebuffer. In the future I'll make this configurable, are allow for variable width reads/writes. For now, this means the read/write interface has to be adapted for the 32 bits CPUs, which is the role of the `32 bits RAM interface` components.

The main SDRAM controller runs at 100MHz in the framework, while our CPUs runs at 50MHz. Therefore I created a clock-domain adaptor for half-speed access, `SDRAM half speed interface`. 

The SDRAM is shared throughout the design. The first 3-way arbiter shares between framebuffer, sdcard streamer and the custom design. The framebuffer, which is always active, gets top priority (in case of simultaneous request, it gets precedence). 

The audio PWMs are here to smooth out the rough 4-bits DAC output. Read more about this in the [audio streaming tutorial](../audio_sdcard_streamer/).

### Using the framework with RISC-V: Code walkthrough

Here is a walkthrough the Silice code assembling this design within the framework.

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

We know have two 32-bits memory interfaces, one for each CPUs. Almost there, but first let's add the instructions caches:

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

Finally, to obtain reasonable audio from the 4-bits DAC, we create the PWMs, on for each left/right channel.

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

An finally the main program:

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

## The instruction 'cache'

The core issue with fitting the design in a full framework built around SDRAM is that the bandwidth is shared, and somewhat pressured by the framebuffer. This is particularly a problem when fetching instructions, as each could take many cycles (10+) to become available. To mitigate this, I created a small component, [basic_cache_ram_32bits.ice](basic_cache_ram_32bits.ice) which sits between the CPU and the SDRAM interface. It implements a naive cache mechanism where read and writes are remembered in a memory space covering the program instructions and stack. Accesses outside of the cached space are safe, but slow. 

The best cache performance is achieved for continuous (serial) accesses, with the next value returned in two cycles if in cache. The worst case is a cache miss during framebuffer operation ... latency goes up to tens of cycles.

## The RiscV processor

This is a RV32I design. It is quite straightforward and is meant to remain simple and easy to modify / hack. Its most 'advanced' feature is that it tries to optimistically fetch the next instructions, before being done with the current one. Together with the instruction cache, this allows many instructions to execute in only 2 cycles. 

The design is not optimized for compactness. For a smaller design please checkout the original [ice-v](../projects/ice-v) which implements an RV32I fitting on an IceStick! (~1182 LUTs with OLED controller).

My [RISC-V RV32I CPU](https://riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf) is a standard design, with an instruction decoder and an ALU orchestrated in the main loop. Let's  focus on the main processor loop (see full code in [ram-ice-v.ice](ram-ice-v.ice)):

```c
while (!halt) {
  // ...
  switch (case_select) {
    
    case 4: { /* LOAD/STORE done */  }

    case 2: { /* next instruction available (after jump or LOAD/STORE) */ exec = true;  }

    case 1: { /* decode + ALU done */ if (/*no jump*/) { exec = true; } }

    default: { /*wait*/ }

  }
  // ...
  if (exec) {
    /* instruction is available, start decoding */
  }
}
```
The CPU boots by requesting the first instruction and waiting. It lands in `case 2` when the instruction is available. This triggers `exec`, which immediately starts execution of the instruction by triggering the decoder and ALU. These run in parallel, and take two cycles. This will land us in `case 1` when decoder and ALU completed. 

In `case 1` we check the instruction result, update registers and do either of three things: 
1. If the instructions jumps, we request the instruction at the jump address and wait. This will land us back to `case 2` when the instruction is available.
2. If the instruction is a LOAD/STORE, we start the memory request and wait. This will land us in `case 4` when data is available. `case 4` updates the registers and requests the next instruction, landing us back again in `case 2`.
3. If the instruction is neither a jump nor a LOAD/STORE, we update the registers and request the next (neighboring) instruction. This will land us back to `case 2` when the instruction is available.

The main cost, by far, is waiting for memory. The instruction cache will greatly mitigate this for the code space itself. So, how long does it take to execute an instruction? As described above, even assuming ultra-fast memory, the best scenario gives us 3 cycles: we request an instruction on cycle `i`, land in `case 2` on `i+1` and trigger ALU+decoder (2 cycles, one each), and finally reach `case 1` at `i+3`.

Now, that is a bit sad because under ideal conditions the cache can answer in just two cycles. The trick here, is to make a bet when starting decoder and ALU in `exec`. We do not know whether a jump will occur or where (because decoder and ALU have not run), but we can make a good guess: very often there is no jump and the next (neighboring) instruction will be needed. Thus, we take a bet and immediately request it in `exec`. If the bet was correct, this will land us back in `case 2` in just two cycles. If we got it wrong, we'll have spent time waiting for data we will not use ... well life is tough for CPUs!

There is a myriad of refinements and subtleties to CPU design (like pipelining and branch prediction). But hopefully this simple example is interesting and might even prove useful for simple tasks!

## The SDRAM controller and arbiter

**TODO**

## Links
* Demo project voices made with https://text-to-speech-demo.ng.bluemix.net/
* RiscV toolchain https://github.com/riscv/riscv-gnu-toolchain
* Pre-compiled riscv-toolchain for Linux https://matthieu-moy.fr/spip/?Pre-compiled-RISC-V-GNU-toolchain-and-spike&lang=en
* Homebrew RISC-V toolchain for macOS https://github.com/riscv/homebrew-riscv
* FemtoRV https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV
* PicoRV  https://github.com/cliffordwolf/picorv32
* Stackoverflow post on CPU design (see answer) https://stackoverflow.com/questions/51592244/implementation-of-simple-microprocessor-using-verilog
