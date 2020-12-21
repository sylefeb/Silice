// -----------------------------------------------------------
// @sylefeb A SDRAM controller in Silice
//
// SDRAM arbitrer

// ------------------------- 
// N-way arbitrer for SDRAM
// sd0 has highest priority, then sd1, then ...

$$if not Nway then
$$  Nway = 3
$$end

algorithm sdram_arbitrer_$Nway$way(
$$for i=0,Nway-1 do
  sdram_provider sd$i$,
$$end  
  sdram_user     sd
) {
	
$$for i=0,Nway-1 do
  sameas(sd$i$) buffered_sd$i$;
$$end  
  
  uint$Nway$ reading   = 0;
  uint1      writing   = 0;
  uint$Nway$ in_valids = uninitialized;

$$for i=0,Nway-1 do
  sd$i$.out_valid := 0; // pulses high when ready
$$end  
  sd .in_valid  := 0; // pulses high when ready
  
  always {
    
    in_valids = {
$$for i=Nway-1,0,-1 do
        buffered_sd$i$.in_valid
$$for j=i-1,0,-1 do
        && !buffered_sd$j$.in_valid
$$end
$$if i > 0 then
       ,
$$end
$$end
    };

    // buffer requests
$$for i=0,Nway-1 do
    if (buffered_sd$i$.in_valid == 0 && sd$i$.in_valid == 1) {
      buffered_sd$i$.addr       = sd$i$.addr;
      buffered_sd$i$.rw         = sd$i$.rw;
      buffered_sd$i$.data_in    = sd$i$.data_in;
      buffered_sd$i$.in_valid   = 1;
    }
$$end    
    // check if read operations terminated
    switch (reading) {
$$for i=0,Nway-1 do
      case $1<<i$ : { 
        if (sd.out_valid == 1) {
          // done
          sd$i$.data_out          = sd.data_out;
          sd$i$.out_valid         = 1;
          reading                 = 0;
          buffered_sd$i$.in_valid = 0;
        }
      }
$$end    
      default: { 
        if (writing) { // when writing we wait on cycle before resuming, 
          writing = 0; // ensuring the sdram controler reports busy properly
        } else {
          if (sd.busy == 0) {
            switch (in_valids) {
$$for i=0,Nway-1 do
              case $1<<i$: {
                sd.addr     = buffered_sd$i$.addr;
                sd.rw       = buffered_sd$i$.rw;
                sd.data_in  = buffered_sd$i$.data_in;
                sd.in_valid = 1;
                if (buffered_sd$i$.rw == 0) { 
                  reading   = $1<<i$; // reading, wait for answer
                } else {
                  writing   = 1;
                  buffered_sd$i$.in_valid = 0; // done if writing
                }
              }            
$$end
              default: { }
            }
          }
        }
      }
    } // switch
    // interfaces are busy while their request is being processed
$$for i=0,Nway-1 do
    sd$i$.busy = buffered_sd$i$.in_valid;
$$end    
  } // always
}

// -----------------------------------------------------------
