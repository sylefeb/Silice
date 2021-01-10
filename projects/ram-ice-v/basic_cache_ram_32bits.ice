// SL 2020-12-22 @sylefeb
//
// Note: clamps addresses to uint26 (beware of mapped adresses using higher bits)
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
$$  cache_depth = 11
$$end
$$cache_size  = 1<<cache_depth

  // cache brams
  simple_dualport_bram uint1  cached_map[$cache_size$] = {pad(0)};
  simple_dualport_bram uint32 cached    [$cache_size$] = uninitialized;
  
  uint24 predicted_addr(24hffffff);
  // track when address is in cache region and onto which entry   
  uint1  in_cache                :=      (pram.addr[0,26]   >> $2+cache_depth$)
                                      == (cache_start[0,26] >> $2+cache_depth$);
  uint$cache_depth$  cache_entry := (pram.addr[0,26] >> 2);
  
  uint1  wait_one(0);
  
  uram.in_valid := 0; // pulsed high when needed
  
  always {
    // cache update rules
    cached.addr1        = cache_entry;
    cached.wenable1     = uram.done & (~uram.rw) & in_cache;
    cached.wdata1       = uram.data_out;
    cached_map.addr1    = cache_entry;
    cached_map.wenable1 = uram.done & (~uram.rw) & in_cache;
    cached_map.wdata1   = 1;
  }
  
  while (1) {
  
    if (pram.in_valid || wait_one) {
      // __display("CACHED MEM access @%h rw:%b datain:%h",pram.addr,pram.rw,pram.data_in);
      if (~wait_one && (predicted_addr != pram.addr[2,24])) {
        cached.addr0     = cache_entry;
        cached_map.addr0 = cache_entry;
        predicted_addr   = 24hffffff;
        wait_one         = 1;        
      } else {
        wait_one         = 0;
        if (in_cache & (cached_map.rdata0 | (pram.rw & pram.wmask == 4b1111))) {
          // write in cache
          cached    .wenable1 = pram.rw;
          cached_map.wenable1 = pram.rw;
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
          // prediction
          predicted_addr   = pram.addr[2,24] + 1;
          cached    .addr0 = (predicted_addr);
          cached_map.addr0 = (predicted_addr);
        } else {
          // relay to used interface
          uram.addr[0,26] = {pram.addr[2,24],2b00};
          uram.data_in    = pram.data_in;
          uram.wmask      = pram.wmask;
          uram.rw         = pram.rw;
          uram.in_valid   = 1;        
        }
      }
    } else {
      pram.data_out = uram.data_out >> {pram.addr[0,2],3b000};
      pram.done     = uram.done;
    }
  }
 
}

