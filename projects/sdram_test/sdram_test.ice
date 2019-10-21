// SDRAM
import('verilog/sdram.v')

// SDRAM simulator
append('verilog/mt48lc32m8a2.v')
import('verilog/simul_sdram.v')

// ------------------------- 

algorithm main() 
{

// --- SDRAM

uint23 saddr       = 0;
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

sdram memory(
  clk       <: clock,
  rst       <: reset,
  addr      <: saddr,
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

  // write 33 in 320 entries
  srw = 1;
  while (count < 320) {
	// write to sdram
	while (1) {
	  if (sbusy == 0) {        // not busy?            
		sdata_in  = 33;            
		saddr     = count;
		sin_valid = 1; // go ahead!
		break;
	  }
	} // write occurs during loop cycle      
	count = count + 1;
  }
  
  count = 0;
  // read back
  srw = 0;
  while (count < 320) {
	if (sbusy == 0) {
	  saddr     = count;
	  sin_valid = 1;         // go ahead!
	  while (sout_valid == 0) { } // wait for value
	  $display("read [%d] = %d",count,sdata_out);
	  count = count + 1;
	}
  }  
}
