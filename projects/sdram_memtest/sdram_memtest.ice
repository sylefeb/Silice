// SL 2020
//
// A simple test for SDRAM controllers, in simulation
//
// ------------------------- 

$include('../common/sdram_interfaces.ice')
// include('../common/sdram_controller_autoprecharge_r128_w8.ice')
$include('../common/sdram_controller_autoprecharge_r16_w16.ice')
$include('../common/sdram_utils.ice')

$$if ICARUS then
// SDRAM simulator
append('../common/mt48lc16m16a2.v')
import('../common/simul_sdram.v')
$$end

$$if ULX3S then
// Clock
import('ulx3s_clk_50_25_100_100ph180.v')
$$end

$$if SIMULATION then
$$  TEST_SIZE = 1<<16
$$else
$$  TEST_SIZE = 1<<24
$$end

// ------------------------- 

algorithm main(
  output uint$NUM_LEDS$ leds,
$$if not ICARUS then
  // SDRAM
  output! uint1  sdram_cle,
  output! uint2  sdram_dqm,
  output! uint1  sdram_cs,
  output! uint1  sdram_we,
  output! uint1  sdram_cas,
  output! uint1  sdram_ras,
  output! uint2  sdram_ba,
  output! uint13 sdram_a,
$$if VERILATOR then
  output! uint1  sdram_clock,
  input   uint16 sdram_dq_i,
  output! uint16 sdram_dq_o,
  output! uint1  sdram_dq_en,
  // VGA (to be compiled with sdram_vga framework)
  output! uint1  video_clock,
  output! uint4  video_r,
  output! uint4  video_g,
  output! uint4  video_b,
  output! uint1  video_hs,
  output! uint1  video_vs
$$else
  output uint1  sdram_clk,  // sdram chip clock != internal sdram_clock
  inout  uint16 sdram_dq,
$$end
$$end
) 
$$if ULX3S then
<@sdram_clock>
$$end
{

// --- SDRAM

$$if ICARUS then

uint1  sdram_cle   = 0;
uint2  sdram_dqm   = 0;
uint1  sdram_cs    = 0;
uint1  sdram_we    = 0;
uint1  sdram_cas   = 0;
uint1  sdram_ras   = 0;
uint2  sdram_ba    = 0;
uint13 sdram_a     = 0;
uint16 sdram_dq    = 0;

simul_sdram simul(
  sdram_clk <:  clock,
  sdram_cle <:  sdram_cle,
  sdram_dqm <:  sdram_dqm,
  sdram_cs  <:  sdram_cs,
  sdram_we  <:  sdram_we,
  sdram_cas <:  sdram_cas,
  sdram_ras <:  sdram_ras,
  sdram_ba  <:  sdram_ba,
  sdram_a   <:  sdram_a,
  sdram_dq  <:> sdram_dq
);

$$end

  // SDRAM interface
  sdram_r16w16_io sio;
  // sdram_r128w8_io sio;
  
  // algorithm
  sdram_controller_autoprecharge_r16_w16 sdram(
  // sdram_controller_autoprecharge_r128_w8 sdram(
    sd        <:> sio,
    sdram_cle :>  sdram_cle,
    sdram_dqm :>  sdram_dqm,
    sdram_cs  :>  sdram_cs,
    sdram_we  :>  sdram_we,
    sdram_cas :>  sdram_cas,
    sdram_ras :>  sdram_ras,
    sdram_ba  :>  sdram_ba,
    sdram_a   :>  sdram_a,
  $$if VERILATOR then
    dq_i      <:  sdram_dq_i,
    dq_o      :>  sdram_dq_o,
    dq_en     :>  sdram_dq_en,
  $$else
    sdram_dq  <:> sdram_dq
  $$end
  );

  uint26               count = 0;
  sameas(sio.data_out) read  = 0;

$$if VERILATOR then
  // sdram clock for verilator simulation
  sdram_clock := clock;
$$end

$$if ULX3S then
  // --- clock
  uint1 video_clock   = 0;
  uint1 sdram_clock   = 0;
  uint1 pll_lock      = 0;
  uint1 compute_clock = 0;
  uint1 compute_reset = 0;
  $$print('ULX3S at 50 MHz compute clock, 100 MHz SDRAM')
  ulx3s_clk_50_25_100_100ph180 clk_gen(
    clkin    <: clock,
    clkout0  :> compute_clock,
    clkout1  :> video_clock,
    clkout2  :> sdram_clock, // controller
    clkout3  :> sdram_clk,   // chip
    locked   :> pll_lock
  ); 
$$end
  
  // maintain low (pulses when ready, see below)
  sio.in_valid := 0;

  __display("=== writing ===");

  // write
  sio.rw = 1;
  while (count < $TEST_SIZE$) {
    // write to sdram
    sio.data_in    = count[0,8];            
    sio.addr       = count;
    sio.in_valid   = 1; // go ahead!
    while (!sio.done) { }
    leds = count[16,8];
$$if SIMULATION then    
    if (count < 16 || count > $TEST_SIZE-16$) {
      __display("write [%x] = %x",count,sio.data_in);
    }
$$end    
    // count          = count + 1; // r128w8
    count = count + 2;
  }

  __display("=== readback ===");
  // read back
  sio.rw = 0;
  count  = 0;
  leds   = 8b01000100;
  while (count < $TEST_SIZE$) {
    sio.addr     = count;
    sio.in_valid = 1; // go ahead!
    while (!sio.done) { }
    read = sio.data_out;
    if (read[0,8] != count[0,8]) {
      leds = 8b00010001;
      __display("ERROR AT %h",count);
    }
$$if SIMULATION then    
    if (count < 16 || count >= $TEST_SIZE-16$) {
      __display("read  [%x] = %x",count,read);
    }
$$end
    // count = count + 16; // r128w8
    count = count + 2;
  }  

}
