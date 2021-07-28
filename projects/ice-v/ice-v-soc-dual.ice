// SL 2020-06-12 @sylefeb
//
// Fun with RISC-V!
// RV32I cpu, see README.md
//
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

// Clocks
$$if ICESTICK then
import('../common/icestick_clk_60.v')
$$end
$$if FOMU then
import('../common/fomu_clk_20.v')
$$end

$$config['bram_wmask_byte_wenable_width'] = 'data'

// pre-compilation script, embeds compiled code within a string
$$dofile('pre_include_asm.lua')

$$addrW = 12

// include the processor
$include('ice-v-dual.ice')

// --------------------------------------------------
// SOC
// --------------------------------------------------

group bram_io
{
  uint4       wenable(0),
  uint32      wdata(0),
  uint32      rdata(0),
  uint$addrW$ addr(0),    // boot address
}

algorithm main( // I guess this is the SOC :-D
  output uint5 leds,
$$if not SIMULATION then    
  ) <@cpu_clock> {
  // clock  
$$if ICESTICK then
  icestick_clk_60 clk_gen (
    clock_in  <: clock,
    clock_out :> cpu_clock
  ); 
$$elseif FOMU then
  uint1 cpu_clock  = uninitialized;
  fomu_clk_20 clk_gen (
    clock_in  <: clock,
    clock_out :> cpu_clock
  );   
$$end
$$else
) {
$$end

$$if SIMULATION then
   uint32 cycle(0);
$$end
	 
  // ram
  // - intermediate interface to perform memory mapping
  bram_io memio;  
  // - uses template "bram_wmask_byte", that turns wenable into a byte mask
  bram uint32 mem<"bram_wmask_byte">[1536] = $meminit$;

  // cpu
  rv32i_cpu cpu( mem <:> memio );

  // io mapping
  always {
	  // ---- memory access
    mem.wenable = memio.wenable & {4{~memio.addr[11,1]}}; 
		//                            ^^^^^^^ no BRAM write if in peripheral addresses
    memio.rdata   = mem.rdata;
    mem.wdata     = memio.wdata;
    mem.addr      = memio.addr;
    // ---- memory mapping to peripherals: writes
    if (/*memio.wenable[0,1] &*/ memio.addr[11,1]) {
      leds      = mem.wdata[0,5] & {5{memio.addr[0,1]}};
$$if SIMULATION then
      if (memio.addr[0,1]) { __display("[cycle %d] LEDs: %b",cycle,leds); }
$$end
    }
$$if SIMULATION then
    cycle = cycle + 1;
$$end
  }

$$if SIMULATION then
  cpu <- ();
	while (cycle < 1024) { }
$$else
  // run the CPU
  () <- cpu <- ();
$$end

}

// --------------------------------------------------
