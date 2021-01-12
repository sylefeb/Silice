// SL 2020-12-02 @sylefeb
// ------------------------- 

$$sdcard_image_pad_size = 0

// pre-compilation script, embeds compile code within sdcard image
$$dofile('pre_include_asm.lua')

$$if SIMULATION then
$$verbose = 1
$$end

$include('ram-ice-v.ice')
$include('bram_ram_32bits.ice')

$include('../common/clean_reset.ice')

import('pll200.v')

// ------------------------- 

algorithm main(
  output uint$NUM_LEDS$ leds
$$if ULX3S then
) <@fast_clock,!fast_reset> {
  uint1 fast_clock = 0;
  uint1 locked = 0;
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
  uint26 predicted_addr = uninitialized;

  // bram io
  bram_ram_32bits bram_ram(
    pram <:> mem,
    predicted_addr <: predicted_addr,
  );

  uint1  cpu_reset      = 1;
  uint26 cpu_start_addr = 26h0000000;
  uint3  cpu_id         = 0;

  // cpu 
  rv32i_cpu cpu<!cpu_reset>(
    boot_at  <:  cpu_start_addr,
    cpu_id   <:  cpu_id,
    ram      <:> mem,
    predicted_addr :> predicted_addr,
  );

  uint16 iter = 0;
  
$$if SIMULATION then  
  while (iter < 4096) {
$$else
  while (1) {
$$end

    cpu_reset = 0;

    if (mem.addr[31,1] & mem.rw) {
      leds       = mem.data_in[0,8];
      __display("LEDs = %b",leds);
    }
    
    iter = iter + 1;

  }
}

// ------------------------- 
