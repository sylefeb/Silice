# SDRAM controller introduction

This project shows how to use the simplest SDRAM controller, which reads and writes 16 bits words. This typically matches the width of the ULX3S and de10nano MiSTer SDRAM chips. 

We will both discuss how to *use* the controller and give some details on the controller itself, which is defined in [dram_controller_autoprecharge_r16_w16.ice](../common/dram_controller_autoprecharge_r16_w16.ice).

But first, let's run this project in simulation!

## Testing

Open a command line in this directory and type:
```
make verilator
```
After some compilation, you should see this output (summarized here):
```
=== writing ===
640 x 480 x 6
Instantiating 64 MB SDRAM : 4 banks x 8192 rows x 1024 cols x 16 bits
write [00000] = 00000
write [00001] = 00001
write [00002] = 00002
...
write [0fffd] = 0fffd
write [0fffe] = 0fffe
write [0ffff] = 0ffff
=== readback ===
read  [00000] = 0000
read  [00001] = 0101
read  [00002] = 0101
...
read  [0fffd] = fdfd
read  [0fffe] = fdfd
read  [0ffff] = ffff
- build.v:138: Verilog $finish
```

The example design has been writing 65336 16bits words in memory and is reading them back. 

**Note:** you can also run in simulation with Icarus, and visualize the signals. Simply type 
```
make icarus
```
gtkwave opens at the end to let you explore what happened within the design.

## Test code walkthrough

The test code is in `sdram_test.ice`. 

First, it includes the controller and SDRAM interface definitions:
```c
$include('../common/sdram_interfaces.ice')
$include('../common/sdram_controller_autoprecharge_r16_w16.ice')
$include('../common/sdram_utils.ice')
```

Then, we declare the SDRAM interface with which we communicate with the chip:
```c
  // SDRAM interface
  sdram_r16w16_io sio;
```

We instantiate the controller, binding it to the interface and the (many) pins:
```c
  // algorithm
  sdram_controller_autoprecharge_r16_w16 sdram(
    sd        <:> sio,
    sdram_cle :>  sdram_cle,
    sdram_dqm :>  sdram_dqm,
    sdram_cs  :>  sdram_cs,
    sdram_we  :>  sdram_we,
    sdram_cas :>  sdram_cas,
    sdram_ras :>  sdram_ras,
    sdram_ba  :>  sdram_ba,
    sdram_a   :>  sdram_a,
  $$if VERILATOR then
    dq_i      <:  sdram_dq_i,
    dq_o      :>  sdram_dq_o,
    dq_en     :>  sdram_dq_en,
  $$else
    sdram_dq  <:> sdram_dq
  $$end
  );
```
Note that Verilator requires a special treatment for the tri-state bus. Wait, the **what?**

Let's stop here for a moment. The SDRAM chip already uses quite many pins, 16 of which are required for reading/writing 16 bits at a time (*Note:* some SDRAM chips have 8 bits interfaces, but for bandwidth more is better). Instead of using two times 16 wires, the chip uses only 16 wires but these are bidirectional: they are used both for reading and writing. This is why the `sdram_dq` pin (the data bus) is bound with two directions: `sdram_dq  <:> sdram_dq`. We'll come back to this when discussing the controller.

So how do we use this controller?

First, we set the `in_valid` field of the interface to low:
```c
  // maintain low (pulses high when ready, see below)
  sio.in_valid := 0;
```
We will set this pin high when we request a read or write, for only one cycle.

Now we enter the write loop:
```c
  // write
  sio.rw = 1;
  while (count < 65536) {
    // write to sdram
    sio.data_in    = count;
    sio.addr       = count;
    sio.in_valid   = 1; // go ahead!
    while (!sio.done) {}
    count          = count + 1;
  }
```
The write request is decomposed in two parts. First we set the data to the interface:
```c
// write to sdram
sio.data_in    = count;
sio.addr       = count;
sio.in_valid   = 1; // go ahead!
```
Note that we previously indicated to be writing with `sio.rw = 1;`.

Then we wait for the request to complete. This is achieved with the loop `while (!sio.done) {}`. Obviously such waits should be minimized, which is why many designs will use a cache.

After writing we enter the readback loop:
```c
  // read back
  sio.rw = 0;
  while (count < 65536) {
    sio.addr     = count;
    sio.in_valid = 1; // go ahead!
    while (!sio.done) {}
    read = sio.data_out;
    if (count < 16 || count > 65520) {
      __display("read  [%x] = %x",count,read);
    }  
    count = count + 1;
  }  
```

This is very similar: we indicate we want to read `sio.rw = 0;`, specify the address `sio.addr = count;` and issue the request by pulsing `sio.in_valid` high. We then wait for data to be available `while (!sio.done) {}`. As soon as `sio.done` pulses one (it stays high only one cycle) the data is available in `sio.data_out`.

And that's it!

## A closer look at the SDRAM controller insides

**TODO**

## Notes

- The Icarus simulation relies on the Micron Semiconductor SDRAM model (mt48lc32m8a2.v).
The SDRAM model Semiconductor cannot be directly imported (too complex for Silice's simple Verilog parser) and is instead wrapped into a simple `simul_sdram.v` module. 
`mt48lc32m8a2.v` is appended to the Silice project (Silice does not parse it, it simply copies it), while the `simul_sdram.v` wrapper is imported.

- The Verilator framework uses a SDRAM simulator embedded with the `verilator_sdram_vga` framework. It was authored by Frederic Requin.


