// MIT license, see LICENSE_MIT in Silice repo root

$$config['simple_dualport_bram_wmask_half_bytes_wenable1_width'] = 'data'

$$if not SPRAM_POSTFIX then
$$  SPRAM_POSTFIX = ''
$$end

algorithm simulation_spram$SPRAM_POSTFIX$(
  input   uint14 addr,
  input   uint16 data_in,
  input   uint4  wmask,
  input   uint1  wenable,
  output! uint16 data_out
) {
  simple_dualport_bram uint16 mem<"simple_dualport_bram_wmask_half_bytes">[16384]
$$if SPRAM_INIT_FILE then  
   = {file($SPRAM_INIT_FILE$),pad(uninitialized)};
$$else
   = uninitialized;
$$end
  always {
    mem.addr0    = addr;
    mem.addr1    = addr;
    mem.wenable1 = {4{wenable}} & wmask;
    mem.wdata1   = data_in;
    data_out     = mem.rdata0;
  }
}
