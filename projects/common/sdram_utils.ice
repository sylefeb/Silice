// -----------------------------------------------------------
// @sylefeb A SDRAM controller in Silice
//
// SDRAM utilities
// - [sdram_half_speed_access] half speed bridge accross clock domains
// - [sdram_byte_readcache]    implements a byte read/write interface, caching the larger read access
// -----------------------------------------------------------

// wrapper for sdram from design running half-speed clock
// the wrapper runs full speed, the design using it half-speed
algorithm sdram_half_speed_access(
  sdram_provider sdh,
  sdram_user     sd
) <autorun> {

  sameas(sdh) buffered_sdh;
  
  uint1 reading   = 0;
  uint1 writing   = 0;
  uint1 in_valid  = uninitialized;

  uint1 half_clock = 0;
  uint2 out_valid  = 0;

  sdh.out_valid := 0; // pulses high when ready
  sd .in_valid  := 0; // pulses high when ready
  
  always {
    
    in_valid = buffered_sdh.in_valid;

    // buffer requests
    if (half_clock) { // read only on slow clock
      if (buffered_sdh.in_valid == 0 && sdh.in_valid == 1) {
        buffered_sdh.addr       = sdh.addr;
        buffered_sdh.rw         = sdh.rw;
        buffered_sdh.data_in    = sdh.data_in;
        buffered_sdh.in_valid   = 1;
      }
    }
    // update out_valid
    out_valid = out_valid >> 1;
    // check if read operations terminated
    if (reading) {
      if (sd.out_valid == 1) {
        // done
        sdh.data_out  = sd.data_out;
        out_valid     = 2b11;
        reading       = 0;
        buffered_sdh.in_valid = 0;
      }
    } else { 
      if (writing) { // when writing we wait on cycle before resuming, 
        writing = 0; // ensuring the sdram controler reports busy properly
      } else {
        if (   sd.busy == 0 && in_valid == 1  ) {
          sd.addr     = buffered_sdh.addr;
          sd.rw       = buffered_sdh.rw;
          sd.data_in  = buffered_sdh.data_in;
          sd.in_valid = 1;
          if (buffered_sdh.rw == 0) { 
            reading               = 1; // reading, wait for answer
          } else {
            writing = 1;
            buffered_sdh.in_valid = 0; // done if writing
          }
        }
      }
    } // reading
    // interface is busy while its request is being processed
    sdh.busy      = buffered_sdh.in_valid;
    // two-cycle out valid
    sdh.out_valid = out_valid[0,1];
    // half clock
    half_clock    = ~ half_clock;
  } // always

}

// -----------------------------------------------------------

// Implements a simplified byte memory interface
//
// Assumptions:
//  * busy     == 1 => in_valid  = 0
//  * in_valid == 1 & rw == 1 => in_valid == 0 until out_valid == 1
//
algorithm sdram_byte_readcache(
  sdram_provider sdb,
  sdram_user     sdr,
) <autorun> {

  // cached reads
  sameas(sdr.data_out) cached = uninitialized;
  uint26  cached_addr         = 26h3FFFFFF;

  uint2   busy           = 1;
  
  always {

    // maintain busy for one clock to
    // account for one cycle latency
    // of latched outputs to chip
    sdb.busy = busy[0,1];
    if (sdr.busy == 0) {
      busy = {1b0,busy[1,1]};
    }

    if (sdb.in_valid) {
      if (sdb.rw == 0) { // reading
        if (sdb.addr[4,22] == cached_addr[4,22]) {
          // in cache!
          sdb.data_out  = cached >> {sdb.addr[0,4],3b000};
          // -> signal availability
          sdb.out_valid = 1;
          // no request
          sdr.in_valid  = 0;
        } else {
          sdb.busy      = 1;
          busy          = 2b11;
          // record addr to cache
          cached_addr   = sdb.addr;
          // issue read
          sdr.rw        = 0;
          sdr.addr      = {cached_addr[4,22],4b0000};
          sdr.in_valid  = 1;
          // no output
          sdb.out_valid = 0;
        }
      } else { // writing
        sdb.busy      = 1;
        busy          = 2b11;
        // issue write
        sdr.rw        = 1;
        sdr.addr      = sdb.addr;
        sdr.data_in   = sdb.data_in;
        sdr.in_valid  = 1; 
        // no output
        sdb.out_valid = 0;
        // invalidate cache
        if (sdb.addr[4,22] == cached_addr[4,22]) {
          cached_addr = 26h3FFFFFF;
        }
      }
    } else {
      if (sdr.out_valid) {
        // data is available
        // -> fill cache
        cached        = sdr.data_out;
        // -> extract byte
        sdb.data_out  = cached >> {cached_addr[0,4],3b000};
        // -> signal availability
        sdb.out_valid = 1;
        // no request
        sdr.in_valid = 0;
      } else {
        // no output
        sdb.out_valid = 0;
        // no request
        sdr.in_valid  = 0;
      }
    }

  }

}

// -----------------------------------------------------------
