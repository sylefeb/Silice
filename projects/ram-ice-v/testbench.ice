// SL 2020-12-02 @sylefeb
//
// *** Testbench ***
// RISC-V with SDRAM IO
// Based on the ice-v
// 
//
// RV32I cpu, see README.txt
//
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.
// --------------------------------------------------

// pre-compilation script, embeds compile code within BRAM
$$dofile('pre_include_asm.lua')

// SHOW_REGS = 1

$include('ram-ice-v.ice')

// --------------------------------------------------

algorithm main(
  output uint8 leds,
) {

  // ram
  bram uint32 mem<input!>[] = $meminit$;
  
  // io
  rv32i_ram_io rio;
  
  uint1 cpu_enable = 0;
  
  // cpu
  rv32i_cpu cpu(
    enable <: cpu_enable,
    ram    <:> rio
  );

$$if SIMULATION then
  uint16 iter = 0;
$$end

  rio.out_valid := 0; // maintain low, pulses high
  
  rio.busy = 0;

  // 'simulate' a ram
$$if SIMULATION then
  while (iter < 4096) {
    iter = iter + 1;
$$else
  while (1) {
$$end

    cpu_enable = 1;
  
    while (!rio.in_valid && iter < 500) { iter = iter + 1; }
  
    rio.busy    = 1;

    __display("RAM access @%h",rio.addr);
    mem.addr    = rio.addr;
    // read 32bit word at addr
    mem.wenable = 0;
++:
    if (rio.rw) {
      __display("RAM write @%h = %h (%b)",rio.addr,rio.data_in,rio.wmask);
      // apply write mask
      mem.wdata = { 
              rio.wmask[3,1] ? rio.data_in[24,8] : mem.rdata[24,8],
              rio.wmask[2,1] ? rio.data_in[16,8] : mem.rdata[16,8],
              rio.wmask[1,1] ? rio.data_in[ 8,8] : mem.rdata[ 8,8],
              rio.wmask[0,1] ? rio.data_in[ 0,8] : mem.rdata[ 0,8]
              };
      // write                
      mem.wenable = 1;
++:
    } else {
      rio.data_out  = mem.rdata;
      rio.out_valid = 1;
      __display("RAM read @%h = %h ",rio.addr,rio.data_out);
    }

    {
      __write("---- RAM dump ----\\n");
      mem.addr = 0;
      while (mem.addr < 256) {
        __write("@%h: %h ",mem.addr,mem.rdata);
        if ((mem.addr & 3) == 3) {
          __write("\\n");
        }
        mem.addr = mem.addr + 1;
      }
      __write("\\n");
    }
    
    rio.busy    = 0;

  }


}

// --------------------------------------------------
