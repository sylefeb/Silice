$$config['simple_dualport_bram_wmask_byte_wenable1_width'] = 'data'

algorithm verilator_spram(
  input   uint14 addr,
  input   uint16 data_in,
  input   uint4  wmask,
  input   uint1  wenable,
  output! uint16 data_out
) {
  simple_dualport_bram uint16 mem<"simple_dualport_bram_wmask_byte">[16384] = uninitialized;
  always {
    mem.addr0    = addr;
    mem.addr1    = addr;
    mem.wenable1 = {2{wenable}} & {wmask[2,1],wmask[0,1]};
    mem.wdata1   = data_in;
    data_out     = mem.rdata0;

    //if (wenable) {
    //  __display("SPRAM waddr: %h data: %h wm:%b we:%b",addr,data_in,wmask,wenable);
    //}

  }
}
