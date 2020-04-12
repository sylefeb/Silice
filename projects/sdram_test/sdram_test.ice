// SDRAM controller
$include('../common/sdramctrl.ice')

// SDRAM simulator
append('../common/mt48lc32m8a2.v')
import('../common/simul_sdram.v')

// ------------------------- 

algorithm main() 
{

// --- SDRAM

uint23 saddr       = 0;
uint2  swbyte_addr = 0;
uint1  srw         = 0;
uint32 sdata_in    = 0;
uint32 sdata_out   = 0;
uint1  sbusy       = 0;
uint1  sin_valid   = 0;
uint1  sout_valid  = 0;

uint1  sdram_cle   = 0;
uint1  sdram_dqm   = 0;
uint1  sdram_cs    = 0;
uint1  sdram_we    = 0;
uint1  sdram_cas   = 0;
uint1  sdram_ras   = 0;
uint2  sdram_ba    = 0;
uint13 sdram_a     = 0;
uint8  sdram_dq    = 0;

simul_sdram simul(
  sdram_clk <: clock,
  <:auto:>
);

sdramctrl memory(
  clk       <: clock,
  rst       <: reset,
  addr      <: saddr,
  wbyte_addr<: swbyte_addr,
  rw        <: srw,
  data_in   <: sdata_in,
  data_out  :> sdata_out,
  busy      :> sbusy,
  in_valid  <: sin_valid,
  out_valid :> sout_valid,
  <:auto:>
);

  uint9  count = 0;

  // maintain low (pulse up when ready)
  sin_valid := 0;

$display("=== writing ===");
  // write index in 320 bytes
  srw = 1;
  while (count < 320) {
    // write to sdram
    while (1) {
      if (sbusy == 0) {        // not busy?            
        sdata_in    = count;            
        saddr       = count >> 2; // word address
        swbyte_addr = count &  3;  // byte within word
        sin_valid   = 1; // go ahead!
        break;
      }
    } // write occurs during loop cycle      
    count = count + 1;
  }
$display("=== readback ===");
  count = 0;
  // read back words (4-bytes)
  srw = 0;
  while (count < 80) {
    if (sbusy == 0) {
      saddr     = count;
      sin_valid = 1;         // go ahead!
      while (sout_valid == 0) { } // wait for value
      $display("read [%x] = %x",count,sdata_out);
      count = count + 1;
    }
  }  
}
