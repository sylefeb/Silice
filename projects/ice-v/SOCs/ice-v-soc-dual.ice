// SL 2020-06-12 @sylefeb
//
// Fun with RISC-V!
// RV32I cpu, see README.md
//
// NOTE: running at 80 MHz while validating ~60 MHz
//       in case of trouble change PLL choice below
//       (plls/icestick_XX)
//
// MIT license, see LICENSE_MIT in Silice repo root

// Clocks
$$if ICESTICK then
import('../../common/plls/icestick_80.v')
$$elseif FOMU then
import('../../common/plls/fomu_20.v')
$$elseif ICEBREAKER then
import('../../common/plls/icebrkr_25.v')
$$end

$$config['bram_wmask_byte_wenable_width'] = 'data'

// pre-compilation script, embeds compiled code within a string
$$dofile('pre_include_compiled.lua')

$$if (ICEBREAKER or SIMULATION) then
$$  USE_SPRAM = 1
$$end

$$if (ICEBREAKER or SIMULATION) then
$$  periph   = 17       -- bit indicating a peripheral is addressed
$$  addrW    = 18       -- additional bits for memory mapping
$$  Boot     = 65536//4 -- NOTE: address in 32bits words
$$  if USE_SPRAM and not SIMULATION then
import('../../common/ice40_spram.v')
$$  end
$$else
$$  periph   = 11    -- bit indicating a peripheral is addressed
$$  addrW    = 12    -- additional bits for memory mapping
$$  Boot     = 0
$$end
$$print('===========> address bus width: ' .. addrW)

$$bramSize = 1024

$$if bramSize > 1<<(addrW-1) then
$$  error("RAM is not fully addressable")
$$end

$$if SIMULATION then
$$  SPRAM_INIT_FILE = nil -- '"../spram_h.img"'
$$  SPRAM_POSTFIX = '_h'
$include('../../common/simulation_spram.ice')
$$  SPRAM_INIT_FILE = nil -- '"../spram_l.img"'
$$  SPRAM_POSTFIX = '_l'
$include('../../common/simulation_spram.ice')
$$end

// include the processor
$include('../CPUs/ice-v-dual.ice')

// --------------------------------------------------
// SOC
// --------------------------------------------------

group bram_io
{
  uint4       wenable(0),
  uint32      wdata(0),
  uint32      rdata(0),
  uint$addrW$ addr($Boot$),
}

algorithm main( // I guess this is the SOC :-D
  output uint5 leds,
$$if OLED then
  output uint1 oled_clk,
  output uint1 oled_mosi,
  output uint1 oled_dc,
  output uint1 oled_resn,
  output uint1 oled_csn(0),
$$end
$$if PMOD then
  inout  uint8 pmod,
$$end
$$if BUTTONS then
  input  uint3 btns,
$$end
$$if SPIFLASH then
  output uint1 sf_clk,
  output uint1 sf_csn,
  output uint1 sf_mosi,
  input  uint1 sf_miso,
$$end  
$$if not SIMULATION then    
  ) <@cpu_clock> {
  // clock  
  uint1 cpu_clock  = uninitialized;
  pll clk_gen (
    clock_in  <: clock,
    clock_out :> cpu_clock
  ); 
$$else
) {
$$end

$$if (ICEBREAKER or SIMULATION) and USE_SPRAM then
  uint14 sp0_addr(0);    uint4  sp0_wmask(0);    uint1  sp0_wenable(0);
  uint16 sp0_data_in(0); uint16 sp0_data_out(0);
  uint14 sp1_addr(0);    uint4  sp1_wmask(0);    uint1  sp1_wenable(0);
  uint16 sp1_data_in(0); uint16 sp1_data_out(0);

$$  if SIMULATION then
  simulation_spram_h spram0(
$$  else
  ice40_spram spram0(
    clock    <: cpu_clock, 
$$  end  
    addr     <: sp0_addr,
    data_in  <: sp0_data_in,
    wenable  <: sp0_wenable,
    wmask    <: sp0_wmask,
    data_out :> sp0_data_out
  );
$$  if SIMULATION then
  simulation_spram_l spram1(
$$  else
  ice40_spram spram1(
    clock    <: cpu_clock,
$$  end  
    addr     <: sp1_addr,
    data_in  <: sp1_data_in,
    wenable  <: sp1_wenable,
    wmask    <: sp1_wmask,
    data_out :> sp1_data_out
  );
$$end

$$if OLED or PMOD then
  uint1 displ_en = uninitialized;
  uint1 displ_dta_or_cmd <: memio.wdata[10,1];
  uint8 displ_byte       <: memio.wdata[0,8];
  oled display(
    enable          <: displ_en,
    data_or_command <: displ_dta_or_cmd,
    byte            <: displ_byte,
    oled_din        :> oled_mosi,
    oled_clk        :> oled_clk,
    oled_dc         :> oled_dc,
  );
$$end

$$if PMOD then
  // audio
  int8  audio_sample(0);
  audio_pcm_i2s audio( sample <: audio_sample );
	// oled
	uint1 oled_clk(0);
  uint1 oled_mosi(0);
  uint1 oled_dc(0);
  uint1 oled_resn(0);
$$end

$$if SPIFLASH or SIMULATION then
  // spiflash
  uint1       reg_miso(0);
  // buttons
  uint3       reg_btns(0);
	// for spiflash memory mapping, need to record prev. cycle addr and rw
	uint$addrW$ prev_mem_addr(0);
$$end
$$if SIMULATION then
   uint32 cycle(0);
$$end
	 
  // ram
  // - intermediate interface to perform memory mapping
  bram_io memio;  
  // - uses template "bram_wmask_byte", that turns wenable into a byte mask
  bram uint32 mem<"bram_wmask_byte">[$bramSize$] = $meminit$;

  // cpu
  rv32i_cpu cpu( mem <:> memio );

  // io mapping
  always {
    uint1 in_periph <: memio.addr[$periph$,1];
    uint4 mem_wmask <: memio.wenable & {4{~in_periph}}; 
		//                                     ^^^^^^^ no write if in peripheral addresses
	  // ---- memory access
$$if USE_SPRAM then
    $$if not SPIFLASH and not SIMULATION then error('USE_SPRAM requires SPIFLASH or SIMULATION') end
    uint1 in_bram      <:  memio.addr[14,1]; // in BRAM if addr greater than 64KB
    uint1 prev_in_bram <:: prev_mem_addr[14,1]; // 14 as we address uint32 instr.
    sp0_data_in   = memio.wdata[ 0,16];
    sp1_data_in   = memio.wdata[16,16];
    sp0_addr      = memio.addr[0,14];
    sp1_addr      = memio.addr[0,14];
    sp0_wmask     = {mem_wmask[1,1],mem_wmask[1,1],mem_wmask[0,1],mem_wmask[0,1]};
    sp1_wmask     = {mem_wmask[3,1],mem_wmask[3,1],mem_wmask[2,1],mem_wmask[2,1]};
    sp0_wenable   = (~in_bram) & (~in_periph) & (mem_wmask != 0);
    sp1_wenable   = (~in_bram) & (~in_periph) & (mem_wmask != 0);
    memio.rdata   = (prev_mem_addr[$periph$,1] & prev_mem_addr[4,1]) 
                  ? {28b0,reg_btns,reg_miso} // ^^^^^^^^^^^^^^^^^^ SPI flash
                  : (prev_in_bram ? mem.rdata : {sp1_data_out,sp0_data_out});
    prev_mem_addr = memio.addr;
    mem.wenable   = {4{in_bram}} & mem_wmask;
$$if VERBOSE then
    if (sp0_wenable) {
      __display("[cycle %d] SPRAM write @%h wmask:%b%b (value: %h)",cycle,
                sp0_addr,sp1_wmask,sp0_wmask,{sp1_data_in,sp0_data_in});
    } else {
      if (~in_bram) {
        __display("[cycle %d] SPRAM read @%h",cycle,sp0_addr<<2);
      }
    }
$$end    
$$else
$$  if SPIFLASH or SIMULATION then
    memio.rdata   = (prev_mem_addr[$periph$,1] & prev_mem_addr[4,1]) 
                  ? {28b0,reg_btns,reg_miso} : mem.rdata; // ^^^^^^ SPI flash
		prev_mem_addr = memio.addr;
$$  else
    memio.rdata   = mem.rdata;
$$  end
    mem.wenable   = mem_wmask;
$$end
    mem.wdata     = memio.wdata;
    mem.addr      = memio.addr;
		// ---- peripherals
$$if OLED or PMOD then
    displ_en      = 0; // maintain display enable low
$$end
$$if PMOD then
    pmod.oenable  = 8b11111111; // pmod all output
    pmod.o        = {audio.i2s,oled_mosi,oled_clk,oled_dc,oled_resn}; // pmod pins
$$end
$$if SPIFLASH then
    reg_miso      = sf_miso; // register flash miso
$$if BUTTONS then    
    reg_btns      = btns;    // register buttons
$$end    
$$end
    // ---- memory mapping to peripherals: writes
    if (memio.wenable[0,1] & memio.addr[$periph$,1]) {
      uint5 select <: memio.addr[0,5];
      onehot (select) {
        case 0: {
          leds      = mem.wdata[0,5];
$$if SIMULATION then
          __display("[cycle %d] LEDs: %b",cycle,leds);
$$end
        }
        case 1: {
$$if OLED or PMOD then
          // command
          displ_en =  mem.wdata[9,1] | mem.wdata[10,1];
$$end
$$if SIMULATION then
          __display("[cycle %d] OLED: %b", cycle, memio.wdata[0,8]);
$$end
        }
        case 2: {
$$if OLED or PMOD then
          // reset
          oled_resn    = ~ mem.wdata[0,1];
$$end
$$if SIMULATION then
          __display("[cycle %d] OLED resn: %b", cycle, ~ mem.wdata[0,1]);
$$end
        }
        case 3: {
$$if PMOD then
          // audio sample
          audio_sample = memio.wdata[0,widthof(audio_sample)];
$$end
$$if SIMULATION then
          __display("[cycle %d] AUDIO: %b", cycle, memio.wdata[0,8]);
$$end
        }
        case 4: {
$$if SPIFLASH then
          sf_clk  = mem.wdata[0,1];
          sf_mosi = mem.wdata[1,1];
          sf_csn  = mem.wdata[2,1];
$$end
$$if SIMULATION then
          __display("[cycle %d] SPI write %b",cycle,mem.wdata[0,3]);
$$end
        }
      }
    }
$$if SIMULATION then
    cycle = cycle + 1;
$$end
  }


$$if SIMULATION then
  // stop after some cycles
	while (cycle < 256) { }
$$else
  // CPU is running
  while (1) { }
$$end

}

// --------------------------------------------------

$$if OLED or PMOD then

$$OLED_SLOW = 1
$include('ice-v-oled.ice')

$$end

// --------------------------------------------------

$$if PMOD then

// Sends 16 bits words to the audio chip (PCM5102)
//
// we use the pre-processor to compute counters
// based on the FPGA frequency and target audio frequency.
// The audio frequency is likely to not be perfectly matched.
//
$$  base_freq_mhz      = 80  -- FPGA frequency
$$  audio_freq_khz     = 44.1 -- Audio frequency (target)
$$  base_cycle_period  = 1000/base_freq_mhz
$$  target_audio_cycle_period = 1000000/audio_freq_khz
$$  bit_hperiod_count  = math.floor(0.5 + (target_audio_cycle_period / base_cycle_period) / 64 / 2)
$$  true_audio_cycle_period = bit_hperiod_count * 64 * 2 * base_cycle_period
// Print out the periods and the effective audio frequency
$$  print('main clock cycle period    : ' .. base_cycle_period .. ' nsec')
$$  print('audio cycle period         : ' .. true_audio_cycle_period .. ' nsec')
$$  print('audio effective freq       : ' .. 1000000 / true_audio_cycle_period .. ' kHz')
$$  print('half period counter        : ' .. bit_hperiod_count)
algorithm audio_pcm_i2s(
  input  int8   sample,
  output uint4  i2s // {i2s_lck,i2s_din,i2s_bck,i2s_sck}
) {

  uint1  i2s_bck(1); // serial clock (32 periods per audio half period)
  uint1  i2s_lck(1); // audio clock (low: right, high: left)
  
  uint8  data(0);    // data being sent, shifted through i2s_din
  uint5  count(0);   // counter for generating the serial bit clock
                     // NOTE: width may require adjustment on other base freqs.
  uint5  mod32(1);   // modulo 32, for audio clock
  
  always {
    
    // track expressions for serial bit clock, edge, negedge, all bits sent
    uint1 edge      <:: (count == $bit_hperiod_count-1$);
    uint1 negedge   <:: edge &  i2s_bck;
    uint1 allsent   <:: mod32 == 0;
  
    // output i2s signals
    i2s = {i2s_lck,data[7,1],i2s_bck,1b0};

    // shift data out on negative edge
    data = negedge ? ( 
                       allsent ? sample         // next audio sample
                               : (data << 1))   // shift next bit (MSB first)
                   : data;
    // NOTE: as we send 8 bits only, the remaining 24 bits are zeros            
    
    // update I2S clocks
    i2s_bck = edge                ? ~i2s_bck : i2s_bck;
    i2s_lck = (negedge & allsent) ? ~i2s_lck : i2s_lck;
    
    // update counter and modulo
    count   = edge    ? 0         : count + 1;
    mod32   = negedge ? mod32 + 1 : mod32;
    
  }

}

$$end

// --------------------------------------------------
