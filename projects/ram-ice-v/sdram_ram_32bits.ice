// SL 2020-12-02 @sylefeb
// ------------------------- 

algorithm sdram_ram_32bits(
  rv32i_ram_provider r32,
  sdram_user         sdr,
) <autorun> {

  uint1  rw        = uninitialized;
  uint4  wmask     = uninitialized;
  uint32 wdata     = uninitialized;
  uint26 addr      = uninitialized;
  
  // single cached read
  uint128 cached      = uninitialized;
  uint26  cached_addr = 26h3FFFFFF;
  
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
        cached_addr   = (addr[4,22] == cached_addr[4,22]) 
                      ? 26h3FFFFFF : cached_addr;
        //__display("R32 write done");
      } else {
        // read
        if (addr[4,22] == cached_addr[4,22]) {
          //__display("R32 read, in cache");
          // in cache
          r32.data_out  = cached >> {addr[0,4],3b000};
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
          cached_addr = addr;
          cached      = sdr.data_out;
          // write output data
          r32.data_out  = cached >> {addr[0,4],3b000};
          // done!
          r32.done  = 1;
          work_todo = 0;
          //__display("R32 read done (cache miss)");
       }
     }  
   }
 }
 
}

