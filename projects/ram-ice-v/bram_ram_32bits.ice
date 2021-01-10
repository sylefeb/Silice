// SL 2020-12-22 @sylefeb
//
// ------------------------- 

algorithm bram_ram_32bits(
  rv32i_ram_provider pram,       // provided ram interface
) <autorun> {

  simple_dualport_bram uint32 mem[] = { $data_bram$ };
  
  uint1 wait_one = 0;
  
$$if false then                          
  uint20 cycle = 0;
$$end  
  
  always {
$$if false then                          
    if (pram.rw & pram.in_valid) {
      __display("[cycle%d] MEM WRITE %b addr_in %h data %h rw %b",cycle,wait_one,pram.addr[2,24],pram.data_in,pram.rw);
    }
$$end
    pram.data_out       =  mem.rdata0;    
    pram.done           = (((mem.addr0 == pram.addr[2,24]) && (pram.addr[26,6] == 0)) || pram.rw)
                          ? (pram.in_valid | wait_one) : 0;
    wait_one            = (pram.in_valid & ~pram.done);
    mem.addr0           = wait_one ? pram.addr[2,24] : (mem.addr0 + (pram.done ? 1 : 0)); // predict
    mem.addr1           = (pram.addr[2,24]);
    mem.wenable1        = pram.rw & pram.in_valid;
    mem.wdata1          = {
                            pram.wmask[3,1] ? pram.data_in[24,8] : mem.rdata0[24,8],
                            pram.wmask[2,1] ? pram.data_in[16,8] : mem.rdata0[16,8],
                            pram.wmask[1,1] ? pram.data_in[ 8,8] : mem.rdata0[ 8,8],
                            pram.wmask[0,1] ? pram.data_in[ 0,8] : mem.rdata0[ 0,8]
                          };   
$$if false then                          
    if (~pram.rw & pram.done) {
      __display("[cycle%d] MEM READ in_valid:%b done:%b wait:%b addr_in:%h data:%h rw:%b pred:@%h",cycle,pram.in_valid,pram.done,wait_one,pram.addr[2,24],mem.rdata0,pram.rw,mem.addr0);
    }
    if (wait_one) {
      __display("[cycle%d] MISPRED in_valid:%b done:%b wait:%b addr_in:%h data:%h rw:%b pred:@%h",cycle,pram.in_valid,pram.done,wait_one,pram.addr[2,24],mem.rdata0,pram.rw,mem.addr0);
    }
    cycle = cycle + 1;
$$end    
  }
}
