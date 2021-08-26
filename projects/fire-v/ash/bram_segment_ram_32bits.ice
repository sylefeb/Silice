// SL 2020-12-22 @sylefeb
//
// ------------------------- 
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

$$if not bram_depth then
$$ bram_depth = 13 --  13: 32 KB, ~90 MHz   14: 64 KB, ~85 MHz
$$end
$$ bram_size  = 1<<bram_depth
$$ print('##### code size: ' .. code_size_bytes .. ' BRAM capacity: ' .. 4*bram_size .. '#####')

$$config['simple_dualport_bram_wmask_byte_wenable1_width'] = 'data'

algorithm bram_segment_ram_32bits(
  rv32i_ram_provider pram,              // provided ram interface
  rv32i_ram_user     uram,              // used ram interface
  input uint26       cache_start,       // where the cache is located
  input uint26       predicted_addr,    // next predicted address
  input uint1        predicted_correct, // was the prediction correct?
) <autorun> {

  // track when address is in cache region and onto which entry   
  uint1  in_cache               <:    (pram.addr  [$2+bram_depth$,$26-2-bram_depth$])
                                   == (cache_start[$2+bram_depth$,$26-2-bram_depth$]);
  uint$bram_depth$  cache_entry <: (pram.addr[2,$bram_depth$]);
  
  simple_dualport_bram uint32 mem<"simple_dualport_bram_wmask_byte">[$bram_size$] = { file("data.img"), pad(uninitialized) };
  
  uint1 not_mapped           <:: ~pram.addr[31,1]; // Note: memory mapped addresses use the top most bits 
  uint$bram_depth$ predicted <:: predicted_addr[2,$bram_depth$];

  uint1 wait_one(0);

$$if verbose then                          
  uint32 cycle = 0;
$$end  
  
  uram.in_valid := 0; // pulsed high when needed
  
  always {
$$if verbose then  
     if (pram.in_valid | wait_one) {
       __display("[cycle%d] in_cache:%b not_mapped:%b in_valid:%b wait:%b addr_in:%h rw:%b prev:@%h predok:%b newpred:@%h data_in:%h",cycle,in_cache,not_mapped,pram.in_valid,wait_one,pram.addr[0,24],pram.rw,mem.addr0<<2,predicted_correct,predicted<<2,pram.data_in);
     }
     if (pram.in_valid && ~predicted_correct && (mem.addr0 == pram.addr[2,$bram_depth$])) {
       __display("########################################### missed opportunity");
     }
     if (~in_cache & pram.in_valid) {
       __display("########################################### outside @%h = %h (%b) cycle %d",pram.addr,pram. data_in,pram.rw,cycle);
     } 
$$end
    // access cache
    pram.data_out       = uram.done 
                        ? (uram.data_out >> {pram.addr[0,2],3b000})
                        : (mem.rdata0    >> {pram.addr[0,2],3b000});
    pram.done           = (predicted_correct & pram.in_valid & in_cache) | wait_one | (pram.rw & in_cache) | uram.done;
    //if (pram.done) {
    //  __display("#### done cycle %d pred:%b wait:%b uram:%b",cycle,predicted_correct & pram.in_valid & in_cache,wait_one,uram.done);
    //}
    mem.addr0           = (pram.in_valid & ~predicted_correct & ~pram.rw) // Note: removing pram.rw does not hurt ...
                          ? pram.addr[2,$bram_depth$] // read addr next (wait_one)
                          : predicted; // predict
    mem.addr1           = pram.addr[2,$bram_depth$];
    mem.wenable1        = pram.wmask & {4{pram.rw & pram.in_valid & not_mapped & in_cache}};
    mem.wdata1          = pram.data_in;    
    // access global ram
    uram.addr           = {6b0,pram.addr[0,26]};
    uram.data_in        = pram.data_in;
    uram.rw             = pram.rw;
    uram.wmask          = pram.wmask;
    uram.in_valid       = ~in_cache & pram.in_valid & not_mapped;

    wait_one            = pram.in_valid & ((~predicted_correct & ~pram.rw & in_cache) | ~not_mapped);

$$if verbose then  
     if (pram.in_valid | wait_one) {                        
       __display("          done:%b wait_one:%b pred:@%h out:%h wen:%b",pram.done,wait_one,mem.addr0,pram.data_out,mem.wenable1[0,4]);  
     }
    cycle = cycle + 1;
$$end    
  }
 
}
