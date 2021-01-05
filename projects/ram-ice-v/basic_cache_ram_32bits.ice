// SL 2020-12-22 @sylefeb
//
// ------------------------- 

algorithm basic_cache_ram_32bits(
  rv32i_ram_provider pram,       // provided ram interface
  rv32i_ram_user     uram,       // used ram interface
  input uint26       cache_start // where the cache is locate
) <autorun> {

$$if SIMULATION then
$$  cache_depth = 11               -- 11 => 8 KB + 2 KB (tag bits)
$$else
$$  cache_depth = 14
$$end
$$cache_size  = 1<<cache_depth

  // cache brams
  simple_dualport_bram uint1  cached_map[$cache_size$] = {pad(0)};
  simple_dualport_bram uint32 cached    [$cache_size$] = uninitialized;
  
  uint32 predicted_addr           = uninitialized;  
  // track when address is in cache region and onto which entry   
  uint1  in_cache                :=      ((pram.addr   >> 2) | $cache_size-1$) 
                                      == ((cache_start >> 2) | $cache_size-1$);
  uint$cache_depth$  cache_entry := (pram.addr >> 2) & ($cache_size-1$);
  
  uint1  work_todo       = 0;
  uint1  cache_predicted = 0;
  
  uram.in_valid := 0; // pulsed high when needed
  
  always {
    pram.done           = uram.done;
    pram.data_out       = uram.done ? (uram.data_out >> {pram.addr[0,2],3b000}) : pram.data_out;
    // cache update rules
    cached.addr1        = cache_entry;
    cached.wenable1     = uram.done & ((~uram.rw) || (pram.wmask == 4b1111)) & in_cache;
    cached.wdata1       = (~uram.rw) ? uram.data_out : pram.data_in;
    cached_map.addr1    = cache_entry;
    cached_map.wenable1 = uram.done & ((~uram.rw) || (pram.wmask == 4b1111)) & in_cache;
    cached_map.wdata1   = 1;
  }
  
  while (1) {
  
    if (work_todo
    || (pram.in_valid 
    && (predicted_addr == pram.addr)
    &&  cache_predicted)    
    ) {
      work_todo     = 0;      
      if (in_cache && cached_map.rdata0) {
        if (pram.rw) {
          // write in cache
          cached    .wenable1 = 1;
          cached    .wdata1   = {
                                 pram.wmask[3,1] ? pram.data_in[24,8] : cached.rdata0[24,8],
                                 pram.wmask[2,1] ? pram.data_in[16,8] : cached.rdata0[16,8],
                                 pram.wmask[1,1] ? pram.data_in[ 8,8] : cached.rdata0[ 8,8],
                                 pram.wmask[0,1] ? pram.data_in[ 0,8] : cached.rdata0[ 0,8]
                               };
        } else {
          // read from cache
          pram.data_out = cached.rdata0 >> {pram.addr[0,2],3b000};
        }
        // done
        pram.done        = 1;          
        // prediction
        predicted_addr   = pram.addr + 4;
        cached    .addr0 = (predicted_addr>>2) & $cache_size-1$;
        cached_map.addr0 = (predicted_addr>>2) & $cache_size-1$;
        cache_predicted  = 1;
      } else {
        // relay to used interface
        uram.addr      = {pram.addr[2,30],2b00};
        uram.data_in   = pram.data_in;
        uram.wmask     = pram.wmask;
        uram.rw        = pram.rw;
        uram.in_valid  = 1;        
      }
    }
   
    // done at the end so the next cycle reads the cache brams
    if (pram.in_valid && !pram.done && !uram.in_valid) {
      cached.addr0     = cache_entry;
      cached_map.addr0 = cache_entry;
      cache_predicted  = 0;
      work_todo        = 1;
    }

  }
 
}

