// SL 2020-06-12 @sylefeb
//
// Fun with RISC-V!
// RV32I cpu, see README.md
//
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

// Clocks
$$if ICESTICK then
import('../common/icestick_clk_60.v')
$$end
$$if FOMU then
import('../common/fomu_clk_20.v')
$$end

$$config['bram_wmask_byte_wenable_width'] = 'data'

// pre-compilation script, embeds compiled code within a string
$$dofile('pre_include_asm.lua')

$$addrW = 12

// include the processor
$$ICE_V_RV32E=nil
$include('ice-v-dual.ice')

// --------------------------------------------------
// SOC
// --------------------------------------------------

group bram_io
{
  uint4       wenable(0),
  uint32      wdata(0),
  uint32      rdata(0),
  uint$addrW$ addr(0),    // boot address
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
$$if SPIFLASH then
  output uint1 sf_clk,
  output uint1 sf_csn,
  output uint1 sf_mosi,
  input  uint1 sf_miso,
$$end  
$$if not SIMULATION then    
  ) <@cpu_clock> {
  // clock  
$$if ICESTICK then
  icestick_clk_60 clk_gen (
    clock_in  <: clock,
    clock_out :> cpu_clock
  ); 
$$elseif FOMU then
  uint1 cpu_clock  = uninitialized;
  fomu_clk_20 clk_gen (
    clock_in  <: clock,
    clock_out :> cpu_clock
  );   
$$end
$$else
) {
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
  bram uint32 mem<"bram_wmask_byte">[1024] = $meminit$;

  // cpu
  rv32i_cpu cpu( mem <:> memio );

  // io mapping
  always {
	  // ---- memory access
    mem.wenable = memio.wenable & {4{~memio.addr[11,1]}}; 
		//                            ^^^^^^^ no BRAM write if in peripheral addresses
$$if SPIFLASH or SIMULATION then
    memio.rdata   = (prev_mem_addr[11,1] & prev_mem_addr[4,1]) ? {31b0,reg_miso} : mem.rdata;
		prev_mem_addr = memio.addr;
$$else
    memio.rdata   = mem.rdata;
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
$$end
    // ---- memory mapping to peripherals: writes
    if (memio.wenable[0,1] & memio.addr[11,1]) {
      uint5 select <: memio.addr[0,5];
      onehot (select) {
        case 0: {
          leds      = mem.wdata[0,5] & {5{memio.addr[0,1]}};
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
	while (cycle < 1024) { }
$$else
  // CPU is running
  while (1) { }
$$end

}

// --------------------------------------------------

$$if OLED or PMOD then

// Sends bytes to the OLED screen
// produces a quarter freq clock with one bit traveling a four bit ring
// data is sent one main clock cycle before the OLED clock raises

algorithm oled(
  input   uint1 enable,   input   uint1 data_or_command, input  uint8 byte,
  output  uint1 oled_clk, output  uint1 oled_din,        output uint1 oled_dc,
) <autorun> {

  uint2 osc        = 1;
  uint1 dc         = 0;
  uint8 sending    = 0;
  uint8 busy       = 0;
  
  always {
    oled_dc  =  dc;
    osc      =  busy[0,1] ? {osc[0,1],osc[1,1]} : 2b1;
    oled_clk =  busy[0,1] && (osc[0,1]); // SPI Mode 0
    if (enable) {
      dc         = data_or_command;
      sending    = {byte[0,1],byte[1,1],byte[2,1],byte[3,1],
                    byte[4,1],byte[5,1],byte[6,1],byte[7,1]};
      busy       = 8b11111111;
    } else {
      oled_din   = sending[0,1];
      sending    = osc[0,1] ? {1b0,sending[1,7]} : sending;
      busy       = osc[0,1] ? busy>>1 : busy;
    }
  }
}

$$end

// --------------------------------------------------

$$if PMOD then

// Sends 16 bits words to the audio chip (PCM5102)
//
// we use the pre-processor to compute counters
// based on the FPGA frequency and target audio frequency.
// The audio frequency is likely to not be perfectly matched.
//
$$  base_freq_mhz      = 60   -- FPGA frequency
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
  uint4  count(0);   // counter for generating the serial bit clock
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
