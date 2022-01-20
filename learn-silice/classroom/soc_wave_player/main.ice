// SL 2022-01-10 @sylefeb
//
// Learning Silice
//
// A simple but feature complete SOC:
// display, UART, sdcard, SPIflash, buttons
//
// Meant to be used on a ULX3S board with SSD1351 SPIscreen
// See README for instructions and exercises
//
// https://github.com/sylefeb/Silice
// MIT license, see LICENSE_MIT in Silice repo root

// Pre-compilation script, embeds compiled code within a string
// - Code has to be compiled into firmware/code.hex before
$$dofile('pre_include_compiled.lua')

// Setup memory
// - we allocate 2^(addrW-1) uint32
// - the topmost bit is used to indicate peripheral access
$$addrW      = 15
$$memmap_bit = addrW-1

// Configure BRAM (needed for write mask)
$$config['bram_wmask_byte_wenable_width'] = 'data'

// Includes the processor
$include('../../../projects/ice-v/CPUs/ice-v.ice')
// Includes the SPIscreen driver
$include('../../../projects/ice-v/SOCs/ice-v-oled.ice')
// Includes the UART controller
$$uart_in_clock_freq_mhz = 25
$$uart_bauds             = 115200
$include('../../../projects/common/uart.ice')

// --------------------------------------------------
// PWM
// --------------------------------------------------

algorithm pwm(
  input  uint8 audio_in,
  output uint4 audio_out) <autorun>
{
  always {
    // simple passthrough   // EXERCISE: implement the actual PWM
    audio_out = audio_in[4,4];
  }
}

// --------------------------------------------------
// SOC
// --------------------------------------------------

// Memory interface between SOC and CPU
group bram_io
{
  uint4       wenable(0), // write enable mask (xxxx, 0:nop, 1:write)
  uint32      wdata(0),   // data to write
  uint32      rdata(0),   // data read from memory
  uint$addrW$ addr(0),    // address, init is boot address
}

// The SOC starts here
// - some input/outputs do not exist in simulation and
//   are therefore enclosed in pre-processor conditions
algorithm main(
  output uint8 leds,
  output uint1 oled_clk,
  output uint1 oled_mosi,
  output uint1 oled_dc,
  output uint1 oled_resn,
  output uint1 oled_csn(0),
$$if BUTTONS then
  input  uint7 btns,
$$end
$$if AUDIO then
  output uint4 audio_l,
  output uint4 audio_r,
$$end
$$if VERILATOR then
  // configuration for SPIscreen simulation
  output uint2  spiscreen_driver(1/*SSD1351*/),
  output uint10 spiscreen_width(128),
  output uint10 spiscreen_height(128),
$$end
$$if SPIFLASH then
  output uint1 sf_clk,
  output uint1 sf_csn,
  output uint1 sf_mosi,
  input  uint1 sf_miso,
$$end
$$if UART then
  output uint1 uart_tx,
  input  uint1 uart_rx,
$$end
$$if SDCARD then
  output  uint1  sd_clk,
  output  uint1  sd_csn,
  output  uint1  sd_mosi,
  input   uint1  sd_miso,
$$end
) {

  // SPIscreen (OLED) controller chip
  uint1 displ_dta_or_cmd <: prev_wdata[10,1];
  uint8 displ_byte       <: prev_wdata[0,8];
  uint1 internal_oled_mosi(0);
  uint1 internal_oled_clk(0);
  uint1 internal_oled_dc(0);
  oled display(
    data_or_command <: displ_dta_or_cmd,
    byte            <: displ_byte,
    oled_din        :> oled_mosi,
    oled_clk        :> oled_clk,
    oled_dc         :> oled_dc,
  );

  // spiflash miso register
  // -> avoid readin a pin directly in design as it is asynchronous
  //    we always track it in a register which updates on clock posedge
  uint1       reg_sf_miso(0);
$$if not SPIFLASH then
  // for simulation ('fake' inputs/outputs)
  uint1       sf_clk(0);
  uint1       sf_csn(0);
  uint1       sf_mosi(0);
  uint1       sf_miso(0);
$$end

  // SDCARD miso register
  uint1        reg_sd_miso(0);
$$if not SDCARD then
  // for simulation ('fake' inputs/outputs)
  uint1  sd_clk(0);
  uint1  sd_csn(0);
  uint1  sd_mosi(0);
  uint1  sd_miso(0);
$$end

  // UART transmit interface
  uart_out uo;
$$if UART then
  // UART transmit chip
  uart_sender usend<reginputs>(
    io      <:> uo,
    uart_tx :>  uart_tx
  );
$$end

  // buttons inputs register
  // -> also an asynchronous signal, so we register it
  uint7 reg_btns(0);
$$if not BUTTONS then
  uint7 btns(0);
$$end

  // audio PWM
  pwm audiopwm;
  // audio bypass for simulation
$$if not AUDIO then
  uint4 audio_l(0);
  uint4 audio_r(0);
$$end

	// for peripherals memory mapping, record previous cycle CPU access
	uint$addrW$ prev_mem_addr(0);
	uint1       prev_mem_rw(0);
  uint32      prev_wdata(0);

$$if SIMULATION then
   // these only exist in simulation for debugging purposes
   uint32 cycle(0);
   uint32 prev_cycle(0);
$$end

  // RAM
  // Instantiate the memory interface
  bram_io memio;
  // Instantiate a BRAM holding the system's RAM
  // -> uses template "bram_wmask_byte", that turns wenable into a byte mask
  bram uint32 mem<"bram_wmask_byte">[$1<<(addrW-1)$] = $meminit$;

  // Instantiate our CPU!
  rv32i_cpu cpu( mem <:> memio );

  // --- SOC logic, the always block is always active
  always {
    // track whether the CPU is reading a memory mapped peripheral
    uint1 memmap_r <:: prev_mem_addr[$memmap_bit$,1] & ~prev_mem_rw;
    //             ^^^ track values at cycle start
    // track memory mapped peripherals access
    uint1 leds_access            <:: prev_mem_addr[0,1];
    uint1 display_en_access      <:: prev_mem_addr[1,1];
    uint1 display_reset_access   <:: prev_mem_addr[2,1];
    uint1 uart_access            <:: prev_mem_addr[3,1];
    uint1 sf_access              <:: prev_mem_addr[4,1];
    uint1 sd_access              <:: prev_mem_addr[5,1];
    // uint1 button_access ... // EXERCISE implement buttons
    uint1 audio_access           <:: prev_mem_addr[7,1];
	  // ---- memory access
    // BRAM wenable update following wenable from CPU<->SOC interface
    mem.wenable = memio.wenable & {4{~memio.addr[$memmap_bit$,1]}};
		//                            ^^^^^^^ no BRAM write if in peripheral addresses
    // data sent to the CPU
    memio.rdata   = // read data is either SPIflash, sdcard or memory
       ((memmap_r & sf_access) ? {31b0,reg_sf_miso} : 32b0)
     | ((memmap_r & sd_access) ? {31b0,reg_sd_miso} : 32b0)
     | (~memmap_r              ? mem.rdata          : 32b0);
    mem.wdata        = memio.wdata;
    mem.addr         = memio.addr;
		// ---- peripherals
    display.enable   = 0;       // maintain display enable low (pulses on use)
    uo.data_in_ready = 0;       // maintain uart trigger low (pulses on use)
    reg_sf_miso      = sf_miso; // register flash miso
    reg_sd_miso      = sd_miso; // register sdcard miso
    reg_btns         = btns;    // register buttons
    audio_l          = audiopwm.audio_out;
    audio_r          = audiopwm.audio_out;
    // ---- memory mapping to peripherals: writes
    if (prev_mem_rw & prev_mem_addr[$memmap_bit$,1]) {
      /// LEDs
      leds           = leds_access ? prev_wdata[0,8] : leds;
      /// display
      // -> whether to send command or data
      display.enable = display_en_access & (prev_wdata[9,1] | prev_wdata[10,1]);
      // -> SPIscreen reset
      oled_resn      = ~ (display_reset_access & prev_wdata[0,1]);
      /// uart
      uo.data_in_ready = ~uo.busy & uart_access;
      uo.data_in       =  uo.data_in_ready ? prev_wdata[ 0,8] : uo.data_in;
      /// SPIflash output pins
			sf_clk  = sf_access ? prev_wdata[0,1] : sf_clk;
			sf_mosi = sf_access ? prev_wdata[1,1] : sf_mosi;
			sf_csn  = sf_access ? prev_wdata[2,1] : sf_csn;
      /// sdcard output pins
      sd_clk  = sd_access ? prev_wdata[0,1] : sd_clk;
      sd_mosi = sd_access ? prev_wdata[1,1] : sd_mosi;
      sd_csn  = sd_access ? prev_wdata[2,1] : sd_csn;
      /// audio
      if (audio_access) { audiopwm.audio_in = prev_wdata[0,8]; }
$$if SIMULATION then
      // Simulation debug output, very convenient during development!
      if (leds_access) {
        __display("[cycle %d] LEDs: %b",cycle,leds);
        if (leds == 255) { __finish(); }// special LED value stops simulation
                                        // convenient to interrupt from firmware
      }
      //if (display_en_access) { // commented to avoid clutter
      //  __display("[cycle %d] display en: %b",cycle,prev_wdata[9,2]);
      //}
      if (display_reset_access) {
        __display("[cycle %d] display resn: %b",cycle,prev_wdata[0,1]);
      }
      if (uart_access) { // printf via UART
        __write("%c",prev_wdata[0,8]);
      }
      if (sf_access) {
        __display("[cycle %d] SPI write %b",cycle,prev_wdata[0,3]);
      }
      if (sd_access) {
        //__display("[cycle %d] sdcard %b (elapsed %d)",cycle,prev_wdata[0,3],cycle - prev_cycle);
        prev_cycle = cycle;
      }
$$end
    }

    // record current access for next cycle memory mapping checks
		prev_mem_addr = memio.addr;
		prev_mem_rw   = memio.wenable[0,1];
    prev_wdata    = memio.wdata;

$$if SIMULATION then
    cycle = cycle + 1;
$$end
  } // end of always block

  // --- algorithm part

  // run the CPU (never returns)
  () <- cpu <- ();

}

// --------------------------------------------------
