// SL 2020-12-02 @sylefeb
// ------------------------- 

algorithm sdram_ram_32bits(
  rv32i_ram_provider r32,
  sdram_user         sdr,
  input uint26       cache_start
) <autorun> {

$$cache_size = 256  
  // cache brams
  bram uint1   cached_map[$cache_size$] = {pad(0)};
  bram uint128 cached    [$cache_size$] = uninitialized;
  // track when address is in cache region and onto which entry
  uint1  in_cache    := (r32.addr | $cache_size-1$) == (cache_start | $cache_size-1$);
  uint8  cache_entry := r32.addr & ($cache_size-1$);
  
  uint1  work_todo = 0;
  
  sdr.in_valid := 0; // pulses high when needed
  r32.done     := 0; // pulses high when needed
  
  always {
    // we track the input impulse in the always block
    // to ensure we won't miss it!
    if (r32.in_valid) {
      work_todo  = 1;
    }
  }
  
  while (1) {
  
    if (work_todo) {
      work_todo = 0;        
      sdr.rw    = r32.rw;
      if (r32.rw) {
        // write
        uint4  write_seq = 4b0001;       
        uint32 tmp = uninitialized;
        uint2  pos = 0;
        //__display("R32 write");
        tmp        = r32.data_in;
        // invalidate cache if writing in same space
        if (in_cache) {
          cached_map.addr    = cache_entry;
          cached_map.wenable = 1;
          cached_map.wdata   = 0;
        }
        while (write_seq != 0) {
          if (sdr.busy == 0) {
            if (r32.wmask & write_seq) {
              sdr.addr     = {r32.addr[2,24],pos};
              sdr.data_in  = tmp[0,8];
              sdr.in_valid = 1;
            }
            pos        = pos + 1;
            tmp        = tmp       >> 8;
            write_seq  = write_seq << 1;        
            r32.done   = (write_seq == 0);
++: // TODO: issue with larger writes not supporting two strobes of in_valid in a row?
          }          
        }
        //__display("R32 write done");
      } else {
        // test cache        
        cached_map.addr    = cache_entry;
        cached_map.wenable = 0;
        cached    .addr    = cache_entry;
        cached    .wenable = 0;
++:
        // read
        if (in_cache && cached_map.rdata) {
          //__display("R32 read, in cache");
          // in cache
          r32.data_out  = cached.rdata >> {r32.addr[0,4],3b000};
          // done!
          r32.done  = 1;
          //__display("R32 read done (in cache)");
        } else {
          //__display("R32 read, cache miss");
          // cache miss
          uint1 done = 0;
          while (!sdr.out_valid) {  
            if (sdr.busy == 0 && done == 0) {
              sdr.addr     = {r32.addr[4,22],4b0000};
              sdr.in_valid = 1;
              done = 1;              
            }
          }
          // update cache
          cached_map.wenable = 1;
          cached_map.wdata   = 1;
          cached    .wenable = 1;
          cached    .wdata   = sdr.data_out;
          // write output data
          r32.data_out  = sdr.data_out >> {r32.addr[0,4],3b000};
          // done!
          r32.done  = 1;
          //__display("R32 read done (cache miss)");
        }
      }  
   }
 }
 
}

