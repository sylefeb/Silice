// SL 2020-12-22 @sylefeb
//
// ------------------------- 

algorithm bram_ram_32bits(
  rv32i_ram_provider pram,       // provided ram interface
) <autorun> {

  simple_dualport_bram uint32 mem[] = { $data_bram$ };
  
  uint1 wait_one(0);
  
  always {
    if (pram.rw & pram.in_valid) {
        __display("MEM WRITE %b addr_in %h data %h rw %b",wait_one,pram.addr,pram.data_in,pram.rw);
    }
    if (wait_one & ~pram.rw) {
      __display("MEM READ  %b addr_in %h data %h rw %b",wait_one,pram.addr,mem.rdata0,pram.rw);
    }
    mem.addr0           = pram.addr>>2;
    mem.addr1           = pram.addr>>2;
    mem.wenable1        = pram.rw & pram.in_valid;
    mem.wdata1          = {
                            pram.wmask[3,1] ? pram.data_in[24,8] : mem.rdata0[24,8],
                            pram.wmask[2,1] ? pram.data_in[16,8] : mem.rdata0[16,8],
                            pram.wmask[1,1] ? pram.data_in[ 8,8] : mem.rdata0[ 8,8],
                            pram.wmask[0,1] ? pram.data_in[ 0,8] : mem.rdata0[ 0,8]
                          };   
    pram.data_out       = mem.rdata0;
    pram.done           = wait_one;
    wait_one            = pram.in_valid;
  }
  
}
