// SL 2020-12-02 @sylefeb
//
// Blaze --- a small, fast but limited Risc-V framework in Silice
//  - runs solely in BRAM
//  - access to LEDs, SDCARD, SPIFLASH
//  - optional WARMBOOT on ice40
//  - [ulx3s] validates at ~100 MHz with a 32KB BRAM
//  - [ulx3s] overclocks up to 200 MHz on the ULX3S
// 
// Tested on: ULX3S, Verilator, Icarus
//
// ------------------------- 
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

$$if SIMULATION then
$$verbose      = 1
$$end

$$if not (ULX3S or ICARUS or VERILATOR or ICEBREAKER) then
$$error('Sorry, Spark is currently not supported on this board.')
$$end

$$if ULX3S then
import('../common/plls/ulx3s_200.v')
$$end

$$if ICEBREAKER then
import('../common/plls/icebrkr_25.v')
$$FIREV_MERGE_ADD_SUB = 1
$$FIREV_NO_INSTRET    = 1
$$if WARMBOOT then
import('../common/ice40_warmboot.v')
$$print('enabling WARMBOOT')
$$end
$$end

// pre-compilation script, embeds code within string for BRAM and outputs sdcard image
$$sdcard_image_pad_size = 0
$$dofile('pre/pre_include_asm.lua')

$include('fire-v/fire-v.ice')
$include('ash/bram_ram_32bits.ice')

$include('../common/clean_reset.ice')

// ------------------------- 

algorithm main(
  output uint$NUM_LEDS$ leds,
$$if SDCARD then
  output! uint1  sd_clk,
  output! uint1  sd_mosi,
  output! uint1  sd_csn,
  input   uint1  sd_miso,
$$end
$$if SPIFLASH then
  output uint1   sf_clk,
  output uint1   sf_csn,
  output uint1   sf_mosi,
  input  uint1   sf_miso,
$$end  
$$if ULX3S then
) <@sys_clock,!sys_reset> {
  uint1 sys_clock = uninitialized;
  uint1 locked    = uninitialized;
  pll pllgen(
    clkin   <: clock,
    clkout0 :> sys_clock,
    locked  :> locked,
  );
  uint1 sys_reset = uninitialized;
  clean_reset rst<!reset>(
    out :> sys_reset
  );
$$elseif ICEBREAKER then
) <@sys_clock,!sys_reset> {
  uint1 sys_clock = uninitialized;
  pll pllgen(
    clock_in  <: clock,
    clock_out :> sys_clock,
  );
  uint1 sys_reset = uninitialized;
  clean_reset rst<@sys_clock,!reset>(
    out :> sys_reset
  );
$$else
) {
$$end

  rv32i_ram_io mem;

  uint26 predicted_addr    = uninitialized;
  uint1  predicted_correct = uninitialized;
  uint32 user_data         = uninitialized;

  // bram io
  bram_ram_32bits bram_ram(
    pram              <:> mem,
    predicted_addr    <:  predicted_addr,
    predicted_correct <:  predicted_correct,
  );

  uint1  cpu_reset = 1;
  uint26 cpu_start_addr(26h0000000); // NOTE: the BRAM ignores the high part of the address
                                     //       but for bit 32 (mapped memory)

  // cpu 
  rv32i_cpu cpu<!cpu_reset>(
    boot_at          <:  cpu_start_addr,
    user_data        <:  user_data,
    ram              <:> mem,
    predicted_addr    :> predicted_addr,
    predicted_correct :> predicted_correct,
  );

$$if WARMBOOT then
  uint1  boot(0);
  uint2  slot(0);
  ice40_warmboot wb(boot <:: boot,slot <:: slot);
$$end

  // sdcard
  uint1  reg_miso(0);

$$if SIMULATION then  
  uint32 iter = 0;
  while (iter != 48) {
    iter = iter + 1;
$$else
  while (1) {
$$end

    cpu_reset = 0;
$$if SDCARD then
    user_data[3,1] = reg_miso;
    reg_miso       = sd_miso;
$$elseif SPIFLASH then    
    user_data[3,1] = reg_miso;
    reg_miso       = sf_miso;
$$end

    if (mem.addr[28,1] & mem.in_valid & mem.rw) {
//      __display("[iter %d] mem.addr %h mem.data_in %h",iter,mem.addr,mem.data_in);
$$if SDCARD or SPIFLASH then
      if (~mem.addr[3,1]) {
        leds = mem.data_in[0,8];
$$  if SIMULATION then            
        __display("[iter %d] LEDs = %b",iter,leds);
$$  end
$$if WARMBOOT then
        boot = boot | mem.data_in[9,1];
				slot = mem.data_in[0,2];
$$end
      } else {
$$  if SDCARD then
        sd_clk  = mem.data_in[0,1];
        sd_mosi = mem.data_in[1,1];
        sd_csn  = mem.data_in[2,1];
$$  elseif SPIFLASH then
        sf_clk  = mem.data_in[0,1];
        sf_mosi = mem.data_in[1,1];
        sf_csn  = mem.data_in[2,1];
$$  end      
$$  if SIMULATION then
        __display("[iter %d] SPI (flash/SD) = %b",iter,mem.data_in[0,3]);
$$  end
      }
$$else
      leds = mem.data_in[0,8];
$$end
    }

  }
}

// ------------------------- 
