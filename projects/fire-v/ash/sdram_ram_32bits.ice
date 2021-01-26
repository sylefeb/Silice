// SL 2020-12-02 @sylefeb
// ------------------------- 

$$if not SDRAM_r512_w64 then
$$  error('[sdram_ram_32bits] expecting the r512w64 controller')
$$end

algorithm sdram_ram_32bits(
  rv32i_ram_provider r32,
  sdram_user         sdr
) <autorun> {
  
  always {
    r32.data_out  = sdr.data_out >> {r32.addr[2,1],5b00000};
    sdr.addr      = {r32.addr[3,23],3b000};
    sdr.rw        = r32.rw;
    sdr.data_in   = r32.data_in << {r32.addr[2,1],5b00000};
    sdr.wmask     = r32.wmask   << {r32.addr[2,1],2b00};
    sdr.in_valid  = r32.in_valid;
    r32.done      = sdr.done;
$$if verbose then
    if (r32.in_valid) {
       __display("[in_valid] @%h rw:%b wmask_in:%b wmask:%b din:%h sdrdin:%h",r32.addr,r32.rw,r32.wmask,sdr.wmask,r32.data_in,sdr.data_in);
    }
$$end    
  }
 
}
