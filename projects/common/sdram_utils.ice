// -----------------------------------------------------------
// @sylefeb A SDRAM controller in Silice
//
// SDRAM utilities
// - [sdram_half_speed_access] half speed bridge accross clock domains
// - [sdram_byte_readcache]    implements a byte read/write interface, caching the larger read access
// -----------------------------------------------------------

// wrapper for sdram from design running half-speed clock
// the wrapper runs full speed, the provided interface at half-speed
algorithm sdram_half_speed_access(
  sdram_provider sdh,
  sdram_user     sd
) <autorun> {

  uint1 half_clock = 0;
  uint2 done       = 0;

  sdh.done     := 0; // pulses high when ready
  sd .in_valid := 0; // pulses high when ready
  
  always {
    // buffer requests
    if (half_clock) { // read only on slow clock
      if (sdh.in_valid == 1) {
        // relay request
        sd.addr       = sdh.addr;
        sd.rw         = sdh.rw;
        sd.data_in    = sdh.data_in;
        sd.in_valid   = 1;
      }
    }
    // update 2-cycle 'done'
    done = done >> 1;
    // check if operation terminated
    if (sd.done == 1) {
      // done
      sdh.data_out = sd.rw ? sdh.data_out : sd.data_out; // update data_out on a read
      done         = 2b11;
    }
    // two-cycle out done
    sdh.done      = done[0,1];
    // half clock
    half_clock    = ~ half_clock;
  } // always

}

// -----------------------------------------------------------

// implements a simplified byte memory interface
algorithm sdram_byte_readcache(
  sdram_provider sdb,
  sdram_user     sdr,
) <autorun> {

  // cached reads
  sameas(sdr.data_out) cached = uninitialized;
  uint26  cached_addr         = 26h3FFFFFF;
  
  always {

    if (sdb.in_valid) {
      if (sdb.rw == 0) { // reading
        if (sdb.addr[4,22] == cached_addr[4,22]) {
          // in cache!
          sdb.data_out  = cached >> {sdb.addr[0,4],3b000};
          // no request
          sdr.in_valid  = 0;
          // done
          sdb.done      = 1;
        } else {
          // record addr to cache
          cached_addr   = sdb.addr;
          // issue read
          sdr.rw        = 0;
          sdr.addr      = {cached_addr[4,22],4b0000};
          sdr.in_valid  = 1;
          // not done
          sdb.done      = 0;
        }
      } else { // writing
        // issue write
        sdr.rw        = 1;
        sdr.addr      = sdb.addr;
        sdr.data_in   = sdb.data_in;
        sdr.in_valid  = 1; 
        // not done
        sdb.done      = 0;
        // invalidate cache
        if (sdb.addr[4,22] == cached_addr[4,22]) {
          cached_addr = 26h3FFFFFF;
        }
      }
    } else {
      if (sdr.done) {
        // sdram is done
        if (sdr.rw == 0) {
          // -> fill cache
          cached        = sdr.data_out;
          // -> extract byte
          sdb.data_out  = cached >> {cached_addr[0,4],3b000};
        }
        // no request
        sdr.in_valid = 0;
        // done
        sdb.done     = 1;
      } else {
        // no request
        sdr.in_valid  = 0;
        // not done
        sdb.done      = 0;
      }
    }

  }

}

// -----------------------------------------------------------
