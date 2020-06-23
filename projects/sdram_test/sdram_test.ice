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
$$end
$$end
)
{

// --- SDRAM

sdio   sio;

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

sdramctrl memory(
  clk       <:  clock,
  rst       <:  reset,
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

  uint16  count = 0;
  uint32  read = 0;

$$if VERILATOR then
  // sdram clock for verilator simulation
  sdram_clock := clock;
$$end
  // maintain low (pulse up when ready, see below)
  sio.in_valid := 0;

$display("=== writing ===");
  // write index in 1024 bytes
  sio.rw = 1;
  while (count < 64) {
    // write to sdram
    while (1) {
      if (sio.busy == 0) {        // not busy?            
        sio.data_in    = count;            
        sio.addr       = count >> 2; // word address
        sio.wbyte_addr = count &  3;  // byte within word
        sio.in_valid   = 1; // go ahead!
        break;
      }
    } // write occurs during loop cycle      
    count = count + 1;
  }
$display("=== readback ===");
  count = 0;
  // read back words (4-bytes)
  sio.rw = 0;
  while (count < 16) {
    if (sio.busy == 0) {
      sio.addr     = count;
      sio.in_valid = 1;         // go ahead!
      while (sio.out_valid == 0) { } // wait for value
      read = sio.data_out;
      $display("read [%x] = %x",count,read);
      count = count + 1;
    }
  }  
}


