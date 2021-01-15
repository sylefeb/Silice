// SL 2020-12-22 @sylefeb
//
// Note: clamps addresses to uint26 (beware of mapped adresses using higher bits)
//
// ------------------------- 

$$config['simple_dualport_bram_wmask_byte_wenable1_width'] = 'data'

algorithm basic_cache_ram_32bits(
  rv32i_ram_provider pram,              // provided ram interface
  rv32i_ram_user     uram,              // used ram interface
  input uint26       cache_start,       // where the cache is locate
  input uint26       predicted_addr,    // next predicted address
  input uint1        predicted_correct, // was the prediction correct?
  input uint32       data_override,     // data used as an override by memory mapper
) <autorun> {

$$if SIMULATION then
$$ bram_depth = 14
$$else
$$ bram_depth = 14
$$end
$$ bram_size  = 1<<bram_depth

  // track when address is in cache region and onto which entry   
  uint1  in_cache               :=    (pram.addr  [$2+bram_depth$,$26-2-bram_depth$])
                                   == (cache_start[$2+bram_depth$,$26-2-bram_depth$]);
  uint$bram_depth$  cache_entry := (pram.addr[2,$bram_depth$]);
  
  simple_dualport_bram uint32 mem<"simple_dualport_bram_wmask_byte">[$bram_size$] = { $data_bram$ pad(uninitialized) };
  
  uint1 in_scope             ::= ~pram.addr[31,1]; // Note: memory mapped addresses use the top most bits 
  uint$bram_depth$ predicted ::= predicted_addr[2,$bram_depth$];

  uint1 wait_one(0);

$$if verbose then                          
  uint32 cycle = 0;
$$end  
  
  uram.in_valid := 0; // pulsed high when needed
  
  always {
$$if verbose then  
     if (pram.in_valid | wait_one) {
       __display("[cycle%d] in_cache:%b in_scope:%b in_valid:%b wait:%b addr_in:%h rw:%b prev:@%h predok:%b newpred:@%h data_in:%h",cycle,in_cache,in_scope,pram.in_valid,wait_one,pram.addr[2,24],pram.rw,mem.addr0,predicted_correct,predicted,pram.data_in);
     }
     if (pram.in_valid && ~predicted_correct && (mem.addr0 == pram.addr[2,$bram_depth$])) {
       __display("########################################### missed opportunity");
     }
     if (~in_cache & pram.in_valid) {
       __display("########################################### in RAM @%h = %h (%b) cycle %d",pram.addr,pram. data_in,pram.rw,cycle);
     } 
$$end
    // access cache
    pram.data_out       = uram.done 
                        ? (uram.data_out >> {pram.addr[0,2],3b000})
                        : (mem.rdata0    >> {pram.addr[0,2],3b000});
      // in_scope ? (mem.rdata0 >> {pram.addr[0,2],3b000}) : data_override;
    pram.done           = (predicted_correct & pram.in_valid & in_cache) | wait_one | (pram.rw & in_cache) | uram.done;
//    if (pram.done) {
//__display("#### done cycle %d pred:%b wait:%b uram:%b",cycle,predicted_correct & pram.in_valid & in_cache,wait_one,uram.done);
    //}
    mem.addr0           = (pram.in_valid & ~predicted_correct & ~pram.rw) // Note: removing pram.rw does not hurt ...
                          ? pram.addr[2,$bram_depth$] // read addr next (wait_one)
                          : predicted; // predict
    mem.addr1           = pram.addr[2,$bram_depth$];
    mem.wenable1        = pram.wmask & {4{pram.rw & pram.in_valid & in_scope & in_cache}};
    mem.wdata1          = pram.data_in;    
    // access global ram
    uram.addr           = {6b0,pram.addr[0,26]};
    uram.data_in        = pram.data_in;
    uram.rw             = pram.rw;
    uram.wmask          = pram.wmask;
    uram.in_valid       = ~in_cache & pram.in_valid;

$$if verbose then  
     if (pram.in_valid | wait_one) {                        
       __display("          done:%b wait_one:%b pred:@%h out:%h wen:%b",pram.done,wait_one,mem.addr0,pram.data_out,mem.wenable1[0,4]);  
     }
    cycle = cycle + 1;
$$end    

    wait_one            = (pram.in_valid & ~predicted_correct & ~pram.rw & in_cache);
  }
 
}
