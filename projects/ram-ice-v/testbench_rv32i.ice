// SL 2020-12-02 @sylefeb
// ------------------------- 

$$sdcard_image_pad_size = 0

// pre-compilation script, embeds compile code within sdcard image
$$dofile('pre_include_asm.lua')

$$if SIMULATION then
$$verbose = nil
$$end

$include('ram-ice-v.ice')
$include('bram_ram_32bits.ice')

$include('../common/clean_reset.ice')

$$if ULX3S then
import('pll200.v')
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
  uint26 cpu_start_addr(26h0000000);

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
  uint16 last = 0;
  uint48 sd_emul = 0;
  uint1  sd_prev = 0;
  while (iter != 8192*4) {
$$else
  while (1) {
$$end

    cpu_reset = 0;
$$if SDCARD then
    user_data = {{28{1b0}},reg_miso,1b0,1b0,1b0};
    reg_miso  = sd_miso;
$$end

    if (mem.addr[28,1] & mem.rw & mem.done) {
      switch (mem.addr[2,2]) {
          case 2b00: {
            leds = mem.data_in[0,8];
$$if SIMULATION then            
            __display("[iter %d] LEDs = %b",iter,leds);
$$end
          }
          case 2b10: {
            // SDCARD
$$if SIMULATION then
            {
            uint1 sd_clk  = uninitialized;
            uint1 sd_mosi = uninitialized;
            uint1 sd_csn  = uninitialized;
            sd_clk  = mem.data_in[0,1];
            sd_mosi = mem.data_in[1,1];
            sd_csn  = mem.data_in[2,1];
            if (sd_csn) {
              sd_emul = 0;
            } else {
              if (sd_clk & ~sd_prev) {
                sd_emul = (sd_emul << 1) | sd_mosi;
                __display("[iter %d] %h",iter,sd_emul);
              }
            }
            sd_prev = sd_clk;
            __display("[iter %d (%d since)] SDCARD %b",iter,iter-last,mem.data_in[0,3]);
            last = iter;
            }
$$end
$$if SDCARD then
            sd_clk  = mem.data_in[0,1];
            sd_mosi = mem.data_in[1,1];
            sd_csn  = mem.data_in[2,1];
$$end
          }           
          default: { }
      }
    }
$$if SIMULATION then  
    iter = iter + 1;
$$end

  }
}

// ------------------------- 
