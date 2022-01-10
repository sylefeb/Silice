// SL 2022-01-10 @sylefeb
//
// Learning Silice
// Meant to be used on a ULX3S board
//
// https://github.com/sylefeb/Silice
// MIT license, see LICENSE_MIT in Silice repo root

// pre-compilation script, embeds compiled code within a string
$$dofile('pre_include_compiled.lua')

$$addrW      = 14
$$memmap_bit = addrW-1

$$config['bram_wmask_byte_wenable_width'] = 'data'

// includes the processor
$include('../../../projects/ice-v/CPUs/ice-v.ice')
// includes the SPIscreen driver
$include('../../../projects/ice-v/SOCs/ice-v-oled.ice')
// includes the UART controller
$$uart_in_clock_freq_mhz = 25
$include('../../../projects/common/uart.ice')

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

algorithm main(
  output uint5 leds,
  output uint1 oled_clk,
  output uint1 oled_mosi,
  output uint1 oled_dc,
  output uint1 oled_resn,
  output uint1 oled_csn(0),
$$if VERILATOR then
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
  output uint1  sd_clk,
  output uint1  sd_csn,
  output uint1  sd_mosi,
  input  uint1  sd_miso,
$$end
) {

  uint1 displ_en = uninitialized;
  uint1 displ_dta_or_cmd <: prev_wdata[10,1];
  uint8 displ_byte       <: prev_wdata[0,8];
  oled display(
    enable          <: displ_en,
    data_or_command <: displ_dta_or_cmd,
    byte            <: displ_byte,
    oled_din        :> oled_mosi,
    oled_clk        :> oled_clk,
    oled_dc         :> oled_dc,
  );

  // spiflash
  uint1       reg_sf_miso(0);
$$if not SPIFLASH then
  uint1       sf_clk(0);
  uint1       sf_csn(0);
  uint1       sf_mosi(0);
  uint1       sf_miso(0);
$$end

  // SDCARD
  uint1        reg_sd_miso(0);
$$if not SDCARD then
  uint1  sd_clk(0);
  uint1  sd_csn(0);
  uint1  sd_mosi(0);
  uint1  sd_miso(0);
$$end

  // UART
  uart_out uo;
$$if UART then
  uart_sender usend<reginputs>(
    io      <:> uo,
    uart_tx :>  uart_tx
  );
$$end

	// for memory mapping, record prev. cycle access
	uint$addrW$ prev_mem_addr(0);
	uint1       prev_mem_rw(0);
  uint32      prev_wdata(0);

$$if SIMULATION then
   uint32 cycle(0);
$$end

  // ram
  // - intermediate interface to perform memory mapping
  bram_io memio;
  // - uses template "bram_wmask_byte", that turns wenable into a byte mask
  bram uint32 mem<"bram_wmask_byte">[$1<<(addrW-1)$] = $meminit$;

  // cpu
  rv32i_cpu cpu( mem <:> memio );

  // io mapping
  always {
	  // ---- memory access
    mem.wenable = memio.wenable & {4{~memio.addr[$memmap_bit$,1]}};
		//                            ^^^^^^^ no BRAM write if in peripheral addresses
    memio.rdata   = (prev_mem_addr[$memmap_bit$,1] & prev_mem_addr[4,1] & ~prev_mem_rw)
                  ? {31b0,reg_sf_miso} // read from SPI-flash
                  : mem.rdata;
    mem.wdata     = memio.wdata;
    mem.addr      = memio.addr;
		// ---- peripherals
    displ_en    = 0; // maintain display enable low
    reg_sf_miso = sf_miso; // register flash miso
    reg_sd_miso = sd_miso; // register sdcard miso
    uo.data_in_ready = 0; // maintain uart trigger low
    // ---- memory mapping to peripherals: writes
    if (prev_mem_rw & prev_mem_addr[$memmap_bit$,1]) {
      /// LEDs
      leds         = prev_mem_addr[0,1] ? prev_wdata[0,5] : leds;
      /// display
      // -> send command/data
      displ_en     = (prev_wdata[9,1] | prev_wdata[10,1]) & prev_mem_addr[1,1];
      // -> reset
      oled_resn    = ~ (prev_wdata[0,1] & prev_mem_addr[2,1]);
      /// uart
      uo.data_in_ready = ~uo.busy & prev_mem_addr[3,1];
      uo.data_in       =  uo.data_in_ready ? prev_wdata[ 0,8] : uo.data_in;
      /// SPIflash
			sf_clk  = prev_mem_addr[4,1] ? prev_wdata[0,1] : sf_clk;
			sf_mosi = prev_mem_addr[4,1] ? prev_wdata[1,1] : sf_mosi;
			sf_csn  = prev_mem_addr[4,1] ? prev_wdata[2,1] : sf_csn;
      /// sdcard
      sd_clk  = prev_mem_addr[5,1] ? prev_wdata[0,1] : sd_clk;
      sd_mosi = prev_mem_addr[5,1] ? prev_wdata[1,1] : sd_mosi;
      sd_csn  = prev_mem_addr[5,1] ? prev_wdata[2,1] : sd_csn;
$$if SIMULATION then
      if (prev_mem_addr[0,1]) {
        __display("[cycle %d] LEDs: %b",cycle,leds);
      }
      //if (prev_mem_addr[1,1]) {
      //  __display("[cycle %d] display en: %b",cycle,prev_wdata[9,2]);
      //}
      if (prev_mem_addr[2,1]) {
        __display("[cycle %d] display resn: %b",cycle,prev_wdata[0,1]);
      }
      if (prev_mem_addr[3,1]) { // printf via UART
        __write("%c",prev_wdata[0,8]);
      }
      if (prev_mem_addr[4,1]) {
        __display("[cycle %d] SPI write %b",cycle,prev_wdata[0,3]);
      }
      if (prev_mem_addr[5,1]) {
        __display("[cycle %d] sdcard %b",cycle,prev_wdata[0,3]);
      }
$$end
    }
		prev_mem_addr = memio.addr;
		prev_mem_rw   = memio.wenable[0,1];
    prev_wdata    = memio.wdata;
$$if SIMULATION then
    cycle = cycle + 1;
$$end
  }

  // run the CPU (never returns)
  () <- cpu <- ();

}

// --------------------------------------------------
