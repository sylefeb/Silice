// SL 2020-12-02 @sylefeb
// ------------------------- 

algorithm sdram_ram_32bits(
  rv32i_ram_provider r32,
  sdram_user         sdr
) <autorun> {

  uint1  work_todo = 0;
  
  uint1  in_valid(0);
  uint1  rw(0);
  uint32 data_in(0);
  uint32 addr(0);
  uint4  wmask(0);

  sdr.in_valid := 0; // pulses high when needed
  r32.done     := 0; // pulses high when needed
  
  in_valid ::= r32.in_valid;
  rw       ::= r32.rw;
  data_in  ::= r32.data_in;
  addr     ::= r32.addr;
  wmask    ::= r32.wmask;

  always {
    // we track the input impulse in the always block
    // to ensure we won't miss it!
    if (in_valid) {
      work_todo  = 1;
    }
    // write output data
    r32.data_out  = sdr.data_out >> {addr[0,4],3b000};
  }
  
  while (1) {
  
    if (work_todo) {
      work_todo = 0;        
      sdr.rw    = rw;
      if (rw) {
        // write
        uint4  write_seq = 4b0001;       
        uint2  pos       = 0;
        uint32 tmp       = uninitialized;
        //__display("RAM   write @%h = %h",r32.addr,r32.data_in);
        tmp              = data_in;
        while (write_seq != 0) {
          if (wmask & write_seq) {
            sdr.addr     = {addr[2,24],pos};
            sdr.data_in  = tmp[0,8];
            sdr.in_valid = 1;
            while (!sdr.done) {}
          }
          pos        = pos + 1;
          tmp        = tmp       >> 8;
          write_seq  = write_seq << 1;        
          r32.done   = (write_seq == 0);
        }
      } else {
        // read
        sdr.addr     = {addr[4,22],4b0000};
        sdr.in_valid = 1;
        while (!sdr.done) {}
        // done!
        r32.done  = 1;
        //__display("RAM   read @%h = %h",r32.addr,r32.data_out);
      }  
    }
    
  }
 
}
