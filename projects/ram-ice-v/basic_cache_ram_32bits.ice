// SL 2020-12-22 @sylefeb
// ------------------------- 

algorithm basic_cache_ram_32bits(
  rv32i_ram_provider pram,       // provided ram interface
  rv32i_ram_user     uram,       // used ram interface
  input uint26       cache_start // where the cache is locate
) <autorun> {

$$cache_depth = 11               -- 11 => 8 KB + 2 KB (tag bits)
$$cache_size  = 1<<cache_depth

  // cache brams
  bram uint1  cached_map[$cache_size$] = {pad(0)};
  bram uint32 cached    [$cache_size$] = uninitialized;
  
  // track when address is in cache region and onto which entry   
  uint1  in_cache                ::=     ((pram.addr   >> 2) | $cache_size-1$) 
                                      == ((cache_start >> 2) | $cache_size-1$);
  uint$cache_depth$  cache_entry ::= (pram.addr >> 2) & ($cache_size-1$);
  
  uint1  work_todo = 0;
  
  uram.in_valid := 0; // pulsed high when needed
  pram.done     := 0;
  
  always {
    // we track the input impulse in the always block
    // to ensure we won't miss it!
    pram.done          = uram.done;
    pram.data_out      = uram.done ? (uram.data_out >> {pram.addr[0,2],3b000}) : pram.data_out;
    cached.addr        = cache_entry;
    cached.wenable     = uram.done & ~uram.rw & in_cache;
    cached.wdata       = uram.data_out;
    cached_map.addr    = cache_entry;
    cached_map.wenable = uram.done & ~uram.rw & in_cache;
    cached_map.wdata   = 1;
  }
  
  while (1) {
  
    if (work_todo) {
      work_todo = 0;        
      if (in_cache && cached_map.rdata) {
        if (pram.rw) {
          //__display("CACHE write @%h = %h",pram.addr,pram.data_in);
          // write in cache
          cached    .wenable = 1;
          cached    .wdata   = {
                                 pram.wmask[3,1] ? pram.data_in[24,8] : cached.rdata[24,8],
                                 pram.wmask[2,1] ? pram.data_in[16,8] : cached.rdata[16,8],
                                 pram.wmask[1,1] ? pram.data_in[ 8,8] : cached.rdata[ 8,8],
                                 pram.wmask[0,1] ? pram.data_in[ 0,8] : cached.rdata[ 0,8]
                               };
          pram.done   = 1;
        } else {
          //__display("CACHE read @%h",pram.addr);        
          // read from cache
          pram.data_out = cached.rdata >> {pram.addr[0,2],3b000};
          pram.done     = 1;          
        }
      } else {
        //__display("CACHE relay rw:%b @%h",pram.rw,pram.addr);        
        // relay to used interface
        uram.addr     = {pram.addr[2,30],2b00};
        uram.data_in  = pram.data_in;
        uram.wmask    = pram.wmask;
        uram.rw       = pram.rw;
        uram.in_valid = 1;        
      }
    }
    
    // done at then end so the next cycle reads the cache
    if (pram.in_valid) {
      work_todo  = 1;
    }

  }
 
}

