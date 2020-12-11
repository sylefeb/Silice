// SL @sylefeb 2020-09
// ------------------------- 

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
  simple_dualport_bram uint8 sdbuffer[512] = uninitialized;

  // SD-card interface
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
  
  sdcio.read_sector := 0;

  always {
    if (stream.next) {
      do_next = 1;
      stream.ready   = 0;
    }
  }

  stream.ready = 0;

  // wait for sdcard to initialize
  while (sdcio.ready == 0) { }

  stream.ready = 1;

  sdcio.addr_sector = 0;
  while (1) {
    if (do_next) {
      do_next = 0;
      // read next sector?
      if (ptr[0,9] == 0) {
        sdcio.read_sector = 1;
        // wait for sdcard
        while (sdcio.ready == 0) { }
        // prepare for next
        sdcio.addr_sector = sdcio.addr_sector + 1;
      }
      sdbuffer.addr0 = ptr[0,9];
++:      
      stream.data    = sdbuffer.rdata0;
      ptr            = ptr + 1;
      stream.ready   = 1;
    }
  }
  
}

// ------------------------- 
