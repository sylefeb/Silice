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
  
  uint1  work_todo = 0;
  
  sdr.in_valid  := 0;
  r32.out_valid := 0;
  
  always {
  
    if (r32.in_valid) {
      rw        = r32.rw;
      wmask     = r32.wmask;
      wdata     = r32.data_in;
      addr      = r32.addr;
      work_todo = 1;
    }

    r32.busy  = work_todo;
   
  }
  
  while (1) {
  
    if (work_todo) {
      sdr.rw       = rw;
      if (rw) {
        uint4  write_seq = 4b0001;       
        uint32 tmp = uninitialized;
        uint2  pos = 0;
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
        work_todo = 0;        
      } else {
        while (sdr.busy)       {  }
        sdr.addr     = addr;
        sdr.in_valid = 1;
        while (!sdr.out_valid) {  }
        if (sdr.addr&1) { // the sdram controller ignores lowest bit on a read (16 bits aligned accesses)
          r32.data_out  = sdr.data_out[8,32];
        } else {
          r32.data_out  = sdr.data_out[0,32];
        }
        r32.out_valid = 1;
        work_todo     = 0;
      }
    }
  
  }

}

