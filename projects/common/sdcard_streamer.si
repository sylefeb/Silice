// SL @sylefeb 2020-09
// -------------------------
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice

group streamio {
  uint1 next  = 0,
  uint8 data  = 0,
  uint1 ready = 0,
}

interface streamio_ctrl {
  input   next,
  output  data,
  output  ready,
}

algorithm sdcard_streamer(
  output  uint1 sd_clk,
  output  uint1 sd_mosi,
  output  uint1 sd_csn,
  input   uint1 sd_miso,
  streamio_ctrl stream
) <autorun> {

  // Read buffer
  simple_dualport_bram uint8 sdbuffer[1024] = uninitialized;
  // Offset to store/read either in the first or second part (one is read while the other is written to)
  uint10 write_offset     = 0;
  uint10 read_offset      = 512;

  // SD-card interface, load sectors
  sdcardio sdcio;
  sdcard sd(
    // pins
    sd_clk  :> sd_clk,
    sd_mosi :> sd_mosi,
    sd_csn  :> sd_csn,
    sd_miso <: sd_miso,
    // read io
    io      <:> sdcio,
    // bram port
    store   <:> sdbuffer,
  );

  // Global pointer in data
  uint32 ptr     = 0;
  uint1  do_next = 0;

  // Maintain low
  sdcio.read_sector := 0;

  always {
    if (stream.next) {
      do_next      = 1;
      stream.ready = 0;
    }
  }

  // wait for sdcard to initialize
  while (sdcio.ready == 0) { }

  // read sector 0
  sdcio.addr_sector = 0;
  sdcio.read_sector = 1;
  // wait for sector 0
  while (sdcio.ready == 0) { }

  // ready
  stream.ready = 1;

  while (1) {

    if (
       ptr[0, 9]        == 9b0                     // changing sector
    && ptr[9,23]        == sdcio.addr_sector[0,23] // not yet changed
    && sdcio.ready      == 1) {                    // sdcard is ready
      // -> swap buffers
      write_offset      = (write_offset == 0) ? 512 : 0;
      read_offset       = (read_offset  == 0) ? 512 : 0;
      sdcio.offset      = write_offset;
      // -> start reading the next sector immediately
      sdcio.addr_sector = ptr[9,23] + 1;
      sdcio.read_sector = 1;
    }

    if (do_next                              // client requested next byte
    && (ptr[9,23] + 1 == sdcio.addr_sector)  // reading next sector
    ) {
      do_next = 0;
      sdbuffer.addr0 = read_offset + ptr[0,9];
++:
      stream.data    = sdbuffer.rdata0;
      ptr            = ptr + 1;
      stream.ready   = 1;
    }
  }

}

// -------------------------
