// SL 2020-12-22 @sylefeb
//
// Note: clamps addresses to uint26 (beware of mapped adresses using higher bits)
//
// ------------------------- 

algorithm basic_cache_ram_32bits(
  rv32i_ram_provider pram,        // provided ram interface
  rv32i_ram_user     uram,        // used ram interface
  input  uint26      cache_start, // where the cache is located
  output uint1       cache_init = 1, // when the cache is ready
) <autorun> {

$$if SIMULATION then
$$  cache_depth = 10               -- 11 => 8 KB + 2 KB (tag bits)
$$else
$$  cache_depth = 11
$$end
$$cache_size  = 1<<cache_depth

  simple_dualport_bram uint32 cached[$cache_size$] = uninitialized;
  
  uint24 predicted_addr(24hffffff);
  
  // track when address is in cache region and onto which entry   
  uint1  in_cache                 :=      (pram.addr[0,26]   >> $2+cache_depth$)
                                       == (cache_start[0,26] >> $2+cache_depth$);
  uint$cache_depth$  cache_entry  := (pram.addr[2,24]);
  
  uint$cache_depth$  next = 0;

  uint1              wait_one = 0;
  
  uram.in_valid   := 0; // pulsed high when needed
  cached.wenable1 := 0;
  
  uram.rw         = 0;
  uram.addr       = cache_start;
  uram.in_valid   = 1;
  while (next != $cache_size-1$) {
    if (uram.done) {
      cached.addr1    = next;
      cached.wdata1   = uram.data_out;
      cached.wenable1 = 1;
      //__display("cache @%h = %h",uram.addr,uram.data_out);
      next            = next + 1;
      uram.addr       = cache_start + (next << 2);
      uram.in_valid   = 1;
    }
  }
  
//__display("CACHE READY");

  while (1) {  
    
    cache_init = 0;
    
    if (pram.in_valid) {
      if (in_cache) {
        //__display("CACHED rw:%b @%h pred:@%h",pram.rw,pram.addr,predicted_addr<<2);
        if ((predicted_addr == pram.addr[2,24]) || pram.rw) {
          // __display("ok");
          // write in cache
          cached    .addr1    = cache_entry;
          cached    .wenable1 = pram.rw;
          cached    .wdata1   = {
                                 pram.wmask[3,1] ? pram.data_in[24,8] : cached.rdata0[24,8],
                                 pram.wmask[2,1] ? pram.data_in[16,8] : cached.rdata0[16,8],
                                 pram.wmask[1,1] ? pram.data_in[ 8,8] : cached.rdata0[ 8,8],
                                 pram.wmask[0,1] ? pram.data_in[ 0,8] : cached.rdata0[ 0,8]
                               };
          // read from cache
          pram.data_out = cached.rdata0 >> {pram.addr[0,2],3b000};
          // done
          pram.done        = 1;          
          //__display("RESULT rw:%b @%h = %h",pram.rw,pram.addr,pram.rw ? cached.wdata1 : pram.data_out);
          // prediction
          predicted_addr   = pram.addr[2,24] + 1;
          cached    .addr0 = predicted_addr;
          wait_one         = 0;
        } else {
          //__display("missed");
          predicted_addr   = 24hffffff;
          cached.addr0     = cache_entry;
          wait_one         = 1;        
        }
      } else {
        //__display("relay");
        // relay to used interface
        uram.addr[0,26] = {pram.addr[2,24],2b00};
        uram.data_in    = pram.data_in;
        uram.wmask      = pram.wmask;
        uram.rw         = pram.rw;
        uram.in_valid   = 1;              
      }
    } else {     
      if (wait_one) {
        wait_one      = 0;
        pram.data_out = cached.rdata0 >> {pram.addr[0,2],3b000};
        // done
        pram.done     = 1;
        // prediction
        predicted_addr   = pram.addr[2,24] + 1;
        cached    .addr0 = predicted_addr;
        //__display("MISS    rw:%b @%h = %h",pram.rw,pram.addr,pram.data_out);
      } else {
        pram.data_out = uram.data_out >> {pram.addr[0,2],3b000};
        pram.done     = uram.done;
      }
    }
    
  } 
}

