// SL 2020-12-22 @sylefeb
//
// ------------------------- 

$$config['simple_dualport_bram_wmask_byte_wenable1_width'] = 'data'

$$ bram_depth = 14 -- 14 : 16K ints - 16 : 64K ints
$$ bram_size  = 1<<bram_depth

algorithm bram_ram_32bits(
  rv32i_ram_provider pram,           // provided ram interface
  input uint26       predicted_addr, // next predicted address
  input uint1        predicted_correct,
  input uint32       data_override,  // data used as an override by memory mapper
) <autorun> {

  simple_dualport_bram uint32 mem<"simple_dualport_bram_wmask_byte">[$bram_size$] = { $data_bram$ pad(uninitialized) };
  
  uint1 in_scope     ::= (pram.addr[28,4] == 4b000); // Note: memory mapped addresses use the top most bits
                                                     // ==> might be better to simply write in a specifc addr (0?)
                                                     // ==> data_override could be written always in some other addr
  uint1 pred_correct ::= predicted_correct;
  uint1 wait_one(0);
  
  uint$bram_depth$ predicted ::= predicted_addr[2,$bram_depth$];

$$if verbose then                          
  uint32 cycle = 0;
$$end  
  
  /*while (1)*/ always {
$$if verbose then  
     if (pram.in_valid | wait_one) {
       //__display("[cycle%d] in_scope:%b in_valid:%b wait:%b addr_in:%h rw:%b prev:@%h predok:%b newpred:@%h data_in:%h",in_scope,cycle,pram.in_valid,wait_one,pram.addr[2,24],pram.rw,mem.addr0,pred_correct,predicted,pram.data_in);
     }
     if (pram.in_valid && ~predicted_correct && (mem.addr0 == pram.addr[2,$bram_depth$])) {
       //__display("########################################### missed opportunity");
     }
$$end
    pram.data_out       = in_scope ? (mem.rdata0 >> {pram.addr[0,2],3b000}) : data_override;
    pram.done           = (pred_correct & pram.in_valid) | wait_one | pram.rw;
    mem.addr0           = (pram.in_valid & ~pred_correct & ~pram.rw) // Note: removing pram.rw does not hurt ...
                          ? pram.addr[2,$bram_depth$] // read addr next (wait_one)
                          : predicted; // predict
    mem.addr1           = pram.addr[2,$bram_depth$];
    mem.wenable1        = pram.wmask & {4{pram.rw & pram.in_valid & in_scope}};
    mem.wdata1          = pram.data_in;    
$$if verbose then  
     if (pram.in_valid | wait_one) {                        
       //__display("          done:%b wait:%b pred:@%h out:%h wen:%b",pram.done,wait_one,mem.addr0,pram.data_out,mem.wenable1[0,4]);  
     }
    cycle = cycle + 1;
$$end    
    wait_one            = (pram.in_valid & ~pred_correct & ~pram.rw );
  }
}
