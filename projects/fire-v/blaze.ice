// SL 2020-12-02 @sylefeb
//
// Blaze --- a small, fast but limited Risc-V framework in Silice
//  - runs solely in BRAM
//  - access to LEDs and SDCARD
//  - validates at ~100 MHz with a 32KB BRAM
//  - overclocks up to 200 MHz on the ULX3S
//
// Test on: ULX3S, Verilator, Icarus
//
// ------------------------- 

$$if SIMULATION then
$$verbose = nil
$$end

$$if not (ULX3S or ICARUS or VERILATOR) then
$$error('Sorry, Blaze is currently not supported on this board.')
$$end

// pre-compilation script, embeds code within string for BRAM and outputs sdcard image
$$sdcard_image_pad_size = 0
$$dofile('pre/pre_include_asm.lua')

$include('fire-v/fire-v.ice')
$include('ash/bram_ram_32bits.ice')

$include('../common/clean_reset.ice')

$$if ULX3S then
import('plls/pll200.v')
$$end

// ------------------------- 

algorithm main(
  output uint$NUM_LEDS$ leds,
$$if SDCARD then
  output! uint1  sd_clk,
  output! uint1  sd_mosi,
  output! uint1  sd_csn,
  input   uint1  sd_miso,
$$end  
$$if ULX3S then
) <@fast_clock,!fast_reset> {
  uint1 fast_clock = 0;
  uint1 locked     = 0;
  pll pllgen(
    clkin   <: clock,
    clkout0 :> fast_clock,
    locked  :> locked,
  );
  uint1 fast_reset = 0;
  clean_reset rst<!reset>(
    out :> fast_reset
  );
$$else
) {
$$end

  rv32i_ram_io mem;

  uint26 predicted_addr    = uninitialized;
  uint1  predicted_correct = uninitialized;
  uint32 user_data(0);

  // bram io
  bram_ram_32bits bram_ram(
    pram              <:> mem,
    predicted_addr    <:  predicted_addr,
    predicted_correct <:  predicted_correct,
  );

  uint1  cpu_reset      = 1;
  uint26 cpu_start_addr(26h0000000); // NOTE: the BRAM ignores the high part of the address
                                     //       but for bit 32 (mapped memory)
                                     //       26h2000000 is chosen for compatibility with Wildfire

  // cpu 
  rv32i_cpu cpu<!cpu_reset>(
    boot_at          <:  cpu_start_addr,
    user_data        <:  user_data,
    ram              <:> mem,
    predicted_addr    :> predicted_addr,
    predicted_correct :> predicted_correct,
  );

  // sdcard
  uint1  reg_miso(0);

$$if SIMULATION then  
  uint32 iter = 0;
  while (iter != 32768) {
    iter = iter + 1;
$$else
  while (1) {
$$end

    cpu_reset = 0;
$$if SDCARD then
    user_data[3,1] = reg_miso;
    reg_miso       = sd_miso;
$$end
    if (mem.addr[28,1] & mem.in_valid & mem.rw) {
//      __display("[iter %d] mem.addr %h mem.data_in %h",iter,mem.addr,mem.data_in);
      if (~mem.addr[3,1]) {
        leds = mem.data_in[0,8];
$$if SIMULATION then            
        __display("[iter %d] LEDs = %b",iter,leds);
$$end
      } else {
        // SDCARD
$$if SIMULATION then            
        __display("[iter %d] SDCARD = %b",iter,mem.data_in[0,3]);
$$end
$$if SDCARD then
        sd_clk  = mem.data_in[0,1];
        sd_mosi = mem.data_in[1,1];
        sd_csn  = mem.data_in[2,1];
$$end
      }
    }

  }
}

// ------------------------- 
