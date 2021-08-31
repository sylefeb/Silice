// SL 2021-08-31 @sylefeb
//
// RV32I SOC
//
// Parameterized by
// - addrW    : width of the address bus
// - memsz    : size of BRAM in 32 bits words
// - meminit  : initialization for BRAM
// - external : bit indicating an IO is accessed
// - io_decl  : io declatations
//
// MIT license, see LICENSE_MIT in Silice repo root

$$config['bram_wmask_byte_wenable_width'] = 'data'

// include the processor
$include('../../../projects/ice-v/CPUs/ice-v.ice')

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

algorithm riscv1($io_decl$) <autorun>
{

$$if SIMULATION then
   uint32 cycle(0);
$$end

  // ram
  // - intermediate interface to perform memory mapping
  bram_io memio;  
  // - uses template "bram_wmask_byte", that turns wenable into a byte mask
  bram uint32 mem<"bram_wmask_byte">[$memsz$] = {$meminit$ pad(uninitialized)};

  // cpu
  rv32i_cpu cpu( mem <:> memio );

  // io mapping
  always {
	  // ---- memory access
    mem.wenable = memio.wenable & {4{~memio.addr[$external$,1]}}; 
		//                            ^^^^^^^ no BRAM write if in peripheral addresses
    memio.rdata = (prev_mem_addr[$external$,1] & prev_mem_addr[4,1] & ~prev_mem_rw) ? {31b0,reg_miso} : mem.rdata;
$$if SMIULATION then		
    if ( prev_mem_addr[$external$,1] & prev_mem_addr[4,1] & ~prev_mem_rw ) { 
      __display("[cycle %d] SPI read: %d",cycle,memio.rdata); 
    }
$$end
		prev_mem_addr = memio.addr;
		prev_mem_rw   = memio.wenable[0,1];
    mem.wdata     = memio.wdata;
    mem.addr      = memio.addr;
		// ---- peripherals
    // ---- memory mapping to peripherals: writes
    if (memio.addr[$external$,1]) {
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
	while (cycle < 2048) { }
$$else
  // run the CPU
  () <- cpu <- ();
$$end

}

// --------------------------------------------------
