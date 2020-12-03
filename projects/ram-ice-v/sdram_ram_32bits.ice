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
      addr      = {r32.addr[24,2],r32.addr[0,22],2b00};
      work_todo = 1;
    }

    r32.busy  = work_todo;
   
  }
  
  while (1) {
  
    if (work_todo) {
      sdr.rw       = rw;
      if (rw) {
        uint4  write_seq = 4b1000;       
        uint32 tmp = uninitialized;
        tmp      = wdata;
        sdr.addr = addr + 3;
        while (write_seq != 0) {
          if (wmask & write_seq) {
            while (sdr.busy) {  }
            sdr.data_in  = tmp[24,8];
            sdr.in_valid = 1;
          }
          sdr.addr   = sdr.addr - 1;
          tmp        = tmp       << 8;
          write_seq  = write_seq >> 1;        
        }
        work_todo = 0;        
      } else {
        while (sdr.busy)       {  }
        sdr.addr     = addr;
        sdr.in_valid = 1;
        while (!sdr.out_valid) {  }
        r32.data_out  = sdr.data_out[0,32];
        r32.out_valid = 1;
        work_todo     = 0;
      }
    }
  
  }

}

