// SL 2022-01-10 @sylefeb
//
// Learning Silice
// Meant to be used on a ULX3S board
//
// https://github.com/sylefeb/Silice
// MIT license, see LICENSE_MIT in Silice repo root

// pre-compilation script, embeds compiled code within a string
$$dofile('pre_include_compiled.lua')

$$addrW = 12

// includes the processor
$include('../../../projects/ice-v/CPUs/ice-v.ice')
// includes the SPIscreen driver
$include('../../../projects/ice-v/SOCs/ice-v-oled.ice')

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
) {

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

  // spiflash
  uint1       reg_miso(0);
$$if not SPIFLASH then
  uint1       sf_clk(0);
  uint1       sf_csn(0);
  uint1       sf_mosi(0);
  uint1       sf_miso(0);
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
  bram uint32 mem<"bram_wmask_byte">[2048] = $meminit$;

  // cpu
  rv32i_cpu cpu( mem <:> memio );

  // io mapping
  always {
	  // ---- memory access
    mem.wenable = memio.wenable & {4{~memio.addr[11,1]}};
		//                            ^^^^^^^ no BRAM write if in peripheral addresses
    memio.rdata   = (prev_mem_addr[11,1] & prev_mem_addr[4,1] & ~prev_mem_rw)
                  ? {31b0,reg_miso} // read from SPI-flash
                  : mem.rdata;
    mem.wdata     = memio.wdata;
    mem.addr      = memio.addr;
		// ---- peripherals
    displ_en  = 0; // maintain display enable low
    reg_miso  = sf_miso; // register flash miso
    // ---- memory mapping to peripherals: writes
    if (prev_mem_rw & prev_mem_addr[11,1]) {
      /// LEDs
      leds      = mem.wdata[0,5] & {5{prev_mem_addr[0,1]}};
      /// display
      // command
      displ_en     = (prev_wdata[9,1] | prev_wdata[10,1]) & prev_mem_addr[1,1];
      // reset
      oled_resn    = ~ (prev_wdata[0,1] & prev_mem_addr[2,1]);
      /// SPIflash
			sf_clk  = prev_mem_addr[4,1] ? prev_wdata[0,1] : sf_clk;
			sf_mosi = prev_mem_addr[4,1] ? prev_wdata[1,1] : sf_mosi;
			sf_csn  = prev_mem_addr[4,1] ? prev_wdata[2,1] : sf_csn;
$$if SIMULATION then
      if (prev_mem_addr[0,1]) {
        __display("[cycle %d] LEDs: %b",cycle,leds); }
      if (prev_mem_addr[1,1]) {
        __display("[cycle %d] display en: %b",cycle,prev_wdata[9,2]);   }
      if (prev_mem_addr[2,1]) {
        __display("[cycle %d] display resn: %b",cycle,prev_wdata[0,1]); }
      if (prev_mem_addr[4,1]) {
        __display("[cycle %d] SPI write %b",cycle,prev_wdata[0,3]); }
$$end
    }
		prev_mem_addr = memio.addr;
		prev_mem_rw   = memio.wenable[0,1];
    prev_wdata    = memio.wdata;
$$if SIMULATION then
    if (cycle == 2048) {
      __finish();
    }
    cycle = cycle + 1;

$$end
  }

  // run the CPU (never returns)
  () <- cpu <- ();

}

// --------------------------------------------------
