// SL 2020-12-02 @sylefeb
// ------------------------- 

$$sdcard_image_pad_size = 0

// pre-compilation script, embeds compile code within sdcard image
$$dofile('pre_include_asm.lua')

$include('ram-ice-v.ice')
$include('bram_ram_32bits.ice')

// ------------------------- 

algorithm main(
  output uint$NUM_LEDS$ leds
) {

  rv32i_ram_io ram;

  // sdram io
  bram_ram_32bits bram_ram(
    pram <:> ram,
  );

  uint1  cpu_enable     = 0;
  uint26 cpu_start_addr = 26h0000000;
  uint3  cpu_id         = 0;

  // cpu 
  rv32i_cpu cpu(
    enable   <:  cpu_enable,
    boot_at  <:  cpu_start_addr,
    cpu_id   <:  cpu_id,
    ram      <:> ram
  );

  uint16 iter = 0;
  while (iter < 512) {
  
    leds       = ram.addr[0,8];
    cpu_enable = 1;

    iter = iter + 1;

  }
}

// ------------------------- 
