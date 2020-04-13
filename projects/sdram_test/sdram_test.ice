// ------------------------- 

// SDRAM controller
$include('../common/sdramctrl.ice')

$$if ICARUS then
// SDRAM simulator
append('../common/mt48lc32m8a2.v')
import('../common/simul_sdram.v')
$$end

// ------------------------- 

algorithm main(
$$if not ICARUS then
  // SDRAM
  output! uint1  sdram_cle,
  output! uint1  sdram_dqm,
  output! uint1  sdram_cs,
  output! uint1  sdram_we,
  output! uint1  sdram_cas,
  output! uint1  sdram_ras,
  output! uint2  sdram_ba,
  output! uint13 sdram_a,
$$if VERILATOR then
  output! uint1  sdram_clock,
  input   uint8  sdram_dq_i,
  output! uint8  sdram_dq_o,
  output! uint1  sdram_dq_en,
  // VGA (to be compiled with sdram_vga framework
  output! uint1  video_clock,
  output! uint4  video_r,
  output! uint4  video_g,
  output! uint4  video_b,
  output! uint1  video_hs,
  output! uint1  video_vs
$$elseif MOJO then
  output! uint1  sdram_clk, // sdram chip clock != internal sdram_clock
  inout   uint8  sdram_dq
$$end
$$end
)
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

$$if ICARUS then

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

$$end

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
$$if VERILATOR then
  dq_i      <: sdram_dq_i,
  dq_o      :> sdram_dq_o,
  dq_en     :> sdram_dq_en,
$$end
  <:auto:>
);

  uint9  count = 0;

$$if VERILATOR then
  // sdram clock for verilator simulation
  sdram_clock := clock;
$$end
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
