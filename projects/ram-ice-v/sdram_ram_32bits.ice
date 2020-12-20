// SL 2020-12-02 @sylefeb
// ------------------------- 

algorithm sdram_ram_32bits(
  rv32i_ram_provider r32,
  sdram_user         sdr,
  input uint26       cache_start
) <autorun> {

  uint1  rw        = uninitialized;
  uint4  wmask     = uninitialized;
  uint32 wdata     = uninitialized;
  uint26 addr      = uninitialized;
  
  // single cached read
  // uint128 cached      = uninitialized;
  // uint26  cached_addr = 26h3FFFFFF;
  
$$cache_size = 256  
  bram uint1   cached_map[$cache_size$] = {pad(0)};
  bram uint128 cached    [$cache_size$] = uninitialized;
  uint1  in_cache    := (r32.addr | $cache_size-1$) == (cache_start | $cache_size-1$);
  uint8  cache_entry := r32.addr & ($cache_size-1$);
  
  uint1  work_todo = 0;
  
  sdr.in_valid := 0;
  r32.done     := 0;
  
  always {
  
    if (r32.in_valid) {
      rw        = r32.rw;
      wmask     = r32.wmask;
      wdata     = r32.data_in;
      addr      = r32.addr;
      work_todo = 1;
      //__display("R32 work todo, rw: %b, at @%h, wdata %h",rw,addr,wdata);
      //__display("R32 work todo, rw: %b, at @%h,  %h == %h ",rw,addr,
      //   (r32.addr | $cache_size-1$),(cache_start | $cache_size-1$));
    }

  }
  
  while (1) {
  
    if (work_todo) {
      sdr.rw       = rw;
      if (rw) {
        // write
        uint4  write_seq = 4b0001;       
        uint32 tmp = uninitialized;
        uint2  pos = 0;
        //__display("R32 write");
        tmp        = wdata;
        while (write_seq != 0) {
          if (wmask & write_seq) {
            while (sdr.busy) {  }
            sdr.addr     = {addr[2,24],pos};
            sdr.data_in  = tmp[0,8];
            sdr.in_valid = 1;
          }
          pos        = pos + 1;
          tmp        = tmp       >> 8;
          write_seq  = write_seq << 1;        
        }
        // done!
        work_todo = 0;        
        r32.done  = 1;
        // invalidate cache if writing in same space
        if (in_cache) {
          cached_map.addr    = cache_entry;
          cached_map.wenable = 1;
          cached_map.wdata   = 0;
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
          r32.data_out  = cached.rdata >> {addr[0,4],3b000};
          // done!
          r32.done  = 1;
          work_todo = 0;
          //__display("R32 read done (in cache)");
        } else {
          //__display("R32 read, cache miss");
          // cache miss
          while (sdr.busy)       {  }
          sdr.addr     = {addr[4,22],4b0000};
          sdr.in_valid = 1;
          while (!sdr.out_valid) {  }
          // update cache
          cached_map.wenable = 1;
          cached_map.wdata   = 1;
          cached    .wenable = 1;
          cached    .wdata   = sdr.data_out;
          // write output data
          r32.data_out  = sdr.data_out >> {addr[0,4],3b000};
          // done!
          r32.done  = 1;
          work_todo = 0;
          //__display("R32 read done (cache miss)");
       }
     }  
   }
 }
 
}

