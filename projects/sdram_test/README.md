# SDRAM controller introduction

This project shows how to use the simplest SDRAM controller, which reads and writes 16 bits words. This typically matches the width of the ULX3S and de10nano MiSTer SDRAM chips. 

We will both discuss how to use the controller and give some details on the controller itself, which is defined in [sdram_controller_autoprecharge_r16_w16.ice](../common/sdram_controller_autoprecharge_r16_w16.ice).

But first, let's run this project in simulation!

**Note:** I am absolutely not an expert in memory controllers, I am just learning, playing and sharing :) There is surely much to improve here. Please let me know your thoughts!

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
write [0000] = 0000
write [0002] = 0002
write [0004] = 0004
...
write [fff8] = fff8
write [fffa] = fffa
write [fffc] = fffc
=== readback ===
read  [0000] = 0000
read  [0002] = 0002
read  [0004] = 0004
...
read  [fff8] = fff8
read  [fffa] = fffa
read  [fffc] = fffc
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

Then, we declare the SDRAM interface through which we communicate with the chip:
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
Note that Verilator requires a special treatment for the tri-state bus. Wait, *the what?*

Let's stop here for a moment. The SDRAM chip already uses quite many pins, 16 of which are required for reading/writing 16 bits at a time (*Note:* some SDRAM chips have 8 bits interfaces, but for bandwidth more is better). Instead of using two times 16 wires, the chip uses only 16 wires but these are bidirectional: they are used both for reading and writing. This is why the `sdram_dq` pin (the data bus) is bound with two directions: `sdram_dq  <:> sdram_dq`. 

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

## A closer look at the SDRAM controller

We are now looking inside [sdram_controller_autoprecharge_r16_w16.ice](../common/sdram_controller_autoprecharge_r16_w16.ice).

Writing an SDRAM controller might be intimidating, but the basics are in fact relatively simple. What makes it more complex, in terms of hardware, are the quite strict requirements on delays when the FPGA and SDRAM chip communicate synchronously -- Josh Basset has a [good writeup on this](https://www.joshbassett.info/sdram-controller/#clocking) in his SDRAM article. What makes it interesting, in terms of design, are the many possible approaches to try to achieve higher bandwidth and lower latencies. This will depend on how your design uses memory of course, and I am still learning and experimenting with this. The [MiSTer cores](https://github.com/MiSTer-devel/Main_MiSTer/wiki) are a good source of examples for SDRAM controllers.

The controller we are considering here is very straightforward: it reads/writes at the native chip width (16 bits) and uses 'auto-precharge' (more on this soon). This is simple but may not be great for your design, as in particular SDRAM chips are able to 'burst' data, amortizing the cost of other operations. For instance a x8 read burst will have some initial latency, but then outputs one 16 bits word every cycles for eight cycles. For instance, the [dram_controller_autoprecharge_r128_w8.ice](../common/dram_controller_autoprecharge_r16_w16.ice) reads in x8 bursts (16x8 bits) and writes single bytes. Many variants are possible.

I said earlier that the controller uses auto-precharge. What does that mean?
Well, SDRAM chips are organized in a very specific way. The memory is decomposed in banks, then rows, then columns. On a typical chip (e.g. AS4C16M16SA) you get something like 4 banks, 8192 rows, 512 columns of 16 bits words (for a grand total of 32MB in this case). 

A 16 bit word is addressed by setting the bank, row, column. The way you map addresses to banks/rows/columns is again an important design choice, and is up to you. For this simple design I chose:
```c
// 4 banks, 8192 rows,  512 columns, 16 bits words
// ============== addr ================================
//   25 24 | 22 -------- 10 |  9 ----- 1 | 0
//   bank  |     row        |   column   | byte (ignored)
// ====================================================
```
(*Note:* I am ignoring the byte bit but keep it there to provide compatibility with controllers able to address individual bytes. With this 16 bits controller all addresses are assumed to be aligned on 16 bits -- multiples of two).

The thing is, you cannot directly address a row in a bank. It has to be `activated` first (think *opening the row*). And once you are done with it, it has to be `pre-charged` (think *closing the row*). These operations, active/pre-charge have a relatively high latency. So for efficiency you'd rather keep a row opened as long as possible -- and of course you have four banks so up to four rows opened at once.

However, this controller does not do that. To avoid any book keeping it always activates and pre-charges rows, every access. Simple brute force! And to avoid having to explictely do the pre-charge, it uses a SDRAM chip feature called `auto-precharge`. This automatically closes the row after this access, simplifying the controller further (and also we do not have to wait explictely for the pre-charge to terminate).

Let's have a closer look at what happens in the code. I'll skip the tricky details of using on-pins flip-flops and such -- which are very important for stability -- keeping them for a later time. I'll focus on the logic of the controller.

A first important component is the `always` block:

```c  
  always { // always block is executed at every cycle before anything else  
    // keep done low, pulse high when done
    sd.done = 0;
    // defaults to NOP command
    cmd = CMD_NOP;
    (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);
    // track in valid here to ensure we never misss a request
    if (sd.in_valid) {
      // -> copy inputs, decompose the address in bank/row/column
      bank      = sd.addr[24, 2]; // bits 24-25
      row       = sd.addr[$SDRAM_COLUMNS_WIDTH+1$, 13];
      col       = sd.addr[                      1, $SDRAM_COLUMNS_WIDTH$];
      data      = sd.data_in;
      do_rw     = sd.rw;    
      // -> signal work to do
      work_todo = 1;
    }
  }
```
This runs every cycle before anything else. The most important part here is `if (sd.in_valid) { ...` where we track input requests. Indeed, as the controller is a multi-cycle affair with waits and such, we could easily miss a request that pulses high for a single cycle.

After that  we have a rather boring initialization sequence that I'll skip. Then we enter the main loop of the controller:

```c
  // init done, start answering requests  
  while (1) {
```

Let us first see how read/write request are answered. We first check if a new request was received while we were busy:
```c
      // any pending request?
      if (work_todo) {
        work_todo = 0;
```
Then we start by opening (activating) the row of the selected bank (the address was decoded in the always block):
```c
        // first, activate the row of the bank
        reg_sdram_ba = bank;
        reg_sdram_a  = row;
        cmd          = CMD_ACTIVE;
        (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);
        $$for i=1,cmd_active_delay do
     ++:
        $$end
```
This simply issues a command to the SDRAM chip, and then waits... (see the `++:`, these wait one cycle). The delay is typically 2 cycles.

We then check if we have to read or write:
```c
        // write or read?
        if (do_rw) {
```
A write takes this path:
```c
          // write
          cmd       = CMD_WRITE;
          (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);
          reg_dq_en     = 1;
          reg_sdram_a   = {2b0, 1b1/*auto-precharge*/, col};
          reg_dq_o      = {data,data};
          // signal done
          sd.done       = 1;
++:       // wait one cycle to enforce tWR
```
This sets the pins, issues the command and signal we are done. However, we have to wait one cycle (`++:`) as the SDRAM chip also has delays between commands. This delay (*after* we signaled being done) ensures that there will be no timing violation.

A read request takes this path:

```c
          // read
          cmd         = CMD_READ;
          (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);
          reg_dq_en       = 0;
          reg_sdram_a     = {2b0, 1b1/*auto-precharge*/, col};          
++:       // wait CAS cycles
++:
++:
++:
$$if ULX3S_IO then
++: // dq_i 2 cycles latency due to flip-flops on output and input path
++:
$$end
          // data is available
          sd.data_out = dq_i;
          sd.done     = 1;
```

Wow, what's with all the delays? Well, there are the CAS delays (time it takes for the chip to answer), plus delays due to the fact that we are registering the input and output pins (and even more on actual hardware due to additional flip-flops on the ins themselves). We pay in latency what we obtain in stability. (*Note: writing this I feel this could be reduced by a couple cycles though ...*)

Now you can hopefully see why reading/writing in bursts is a good idea!

We are almost done, but there is a last very important detail. SDRAM chips store data in capacitors, and these capacitors leak! They have to be periodically refreshed. This is why we count cycles in `refresh_count` and do this when the delay elapsed:

```c
    // refresh?
    if (refresh_count == 0) {

      // refresh
      cmd           = CMD_REFRESH;
      (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);
      // wait
      () <- wait <- ($refresh_wait-3$);
      // -> reset count
      refresh_count = $refresh_cycles$;  

    } else { // ...

```

This requests a refresh of the memory chip. Meanwhile nothing else can happen...

And that's it. A basic, functional SDRAM controller.

## Notes

- The Icarus simulation relies on the Micron Semiconductor SDRAM model (mt48lc32m8a2.v).
The SDRAM model Semiconductor cannot be directly imported (too complex for Silice's simple Verilog parser) and is instead wrapped into a simple `simul_sdram.v` module. 
`mt48lc32m8a2.v` is appended to the Silice project (Silice does not parse it, it simply copies it), while the `simul_sdram.v` wrapper is imported.

- The Verilator framework uses a SDRAM simulator embedded with the `verilator_sdram_vga` framework. It was authored by Frederic Requin.

## Links
- Josh Bassett SDRAM controller (source on github, follow links) https://www.joshbassett.info/sdram-controller/
