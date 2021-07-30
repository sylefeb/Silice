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
	// oled
	uint1 oled_clk(0);
  uint1 oled_mosi(0);
  uint1 oled_dc(0);
  uint1 oled_resn(0);
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
    memio.rdata   = mem.rdata;
    mem.wdata     = memio.wdata;
    mem.addr      = memio.addr;
		// ---- peripherals
$$if OLED or PMOD then
    displ_en = 0; // maintain display enable low
$$end
$$if PMOD then
    pmod.oenable = 8b11111111; // pmod all output
    pmod.o       = {4b0,oled_mosi,oled_clk,oled_dc,oled_resn}; // pmod pins
$$end
    // ---- memory mapping to peripherals: writes
    if (memio.wenable[0,1] & memio.addr[11,1]) {
      uint3 select <: memio.addr[0,3];
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
          displ_en     =   (mem.wdata[9,1] | mem.wdata[10,1]) & memio.addr[1,1];      
$$if SIMULATION then
          __display("[cycle %d] OLED: %b", cycle, memio.wdata[0,8]);
$$end
$$end
        }
        case 2: {
$$if OLED or PMOD then
          // reset
          oled_resn    = ~ (mem.wdata[0,1] & memio.addr[2,1]);
$$end
        }
      }
    }
$$if SIMULATION then
    cycle = cycle + 1;
$$end
  }


$$if SIMULATION then
//  cpu <- ();
	while (cycle < 100000) { }
$$else
  // run the CPU
//  () <- cpu <- ();
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
      oled_dc    = dc;
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
