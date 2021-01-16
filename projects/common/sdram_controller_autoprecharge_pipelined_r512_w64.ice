// -----------------------------------------------------------
// @sylefeb A SDRAM controller in Silice
//
// Pipelined SDRAM controller with auto-precharge
// - expects a 16 bits wide SDRAM interface
// - writes           4 x 16 bits
// - reads bursts of 32 x 16 bits
//
// if using directly the controller: 
//  - reads/writes have to align with 16 bits boundaries (even byte addresses)

// 4 banks, 8192 rows,  512 columns, 16 bits words
// (larger chips will be left unused, see comments in other controllers)
// ============== addr ================================
//   | 24 -------- 12 | 11 ----- 3 | 2--1 | 0
//   |     row        |   column   | bank | byte (H/L)
// ====================================================

//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

$$ SDRAM_COLUMNS_WIDTH =  9

import('inout16_set.v')

$$if ULX3S then
import('inout16_ff_ulx3s.v')
import('out1_ff_ulx3s.v')
import('out2_ff_ulx3s.v')
import('out13_ff_ulx3s.v')
$$ULX3S_IO = true
$$end

// -----------------------------------------------------------

circuitry command(
  output sdram_cs,output sdram_ras,output sdram_cas,output sdram_we,input cmd)
{
  sdram_cs  = cmd[3,1];
  sdram_ras = cmd[2,1];
  sdram_cas = cmd[1,1];
  sdram_we  = cmd[0,1];
}

// -----------------------------------------------------------

$$ burst_config      = '3b011'
$$ read_burst_length = 8

algorithm sdram_controller_autoprecharge_pipelined_r512_w64(
    // sdram pins
    // => we use immediate (combinational) outputs as these are registered 
    //    explicitely using dedicated primitives when available / implemented
    output! uint1   sdram_cle,
    output! uint1   sdram_cs,
    output! uint1   sdram_cas,
    output! uint1   sdram_ras,
    output! uint1   sdram_we,
    output! uint2   sdram_dqm,
    output! uint2   sdram_ba,
    output! uint13  sdram_a,
    // data bus
$$if VERILATOR then
    input   uint16  dq_i,
    output! uint16  dq_o,
    output! uint1   dq_en,
$$else
    inout   uint16  sdram_dq,
$$end
    // interface
    sdram_provider sd, // TODO: add a wmask
$$if SIMULATION then        
    output uint1 error,
$$end        
) <autorun>
{

  // SDRAM commands
  uint4 CMD_UNSELECTED    = 4b1000;
  uint4 CMD_NOP           = 4b0111;
  uint4 CMD_ACTIVE        = 4b0011;
  uint4 CMD_READ          = 4b0101;
  uint4 CMD_WRITE         = 4b0100;
  uint4 CMD_TERMINATE     = 4b0110;
  uint4 CMD_PRECHARGE     = 4b0010;
  uint4 CMD_REFRESH       = 4b0001;
  uint4 CMD_LOAD_MODE_REG = 4b0000;

  uint1   reg_sdram_cs  = uninitialized;
  uint1   reg_sdram_cas = uninitialized;
  uint1   reg_sdram_ras = uninitialized;
  uint1   reg_sdram_we  = uninitialized;
  uint2   reg_sdram_dqm = uninitialized;
  uint2   reg_sdram_ba  = uninitialized;
  uint13  reg_sdram_a   = uninitialized;
  uint16  reg_dq_o(0);
  uint1   reg_dq_en(0);

$$if not VERILATOR then

  uint16 dq_i = uninitialized;

$$if ULX3S_IO then

  inout16_ff_ulx3s ioset(
    clock           <:  clock,
    io_pin          <:> sdram_dq,
    io_write        <:: reg_dq_o,
    io_read         :>  dq_i,
    io_write_enable <:: reg_dq_en
  );

  out1_ff_ulx3s  off_sdram_cs (clock <: clock, pin :> sdram_cs , d <:: reg_sdram_cs );
  out1_ff_ulx3s  off_sdram_cas(clock <: clock, pin :> sdram_cas, d <:: reg_sdram_cas);
  out1_ff_ulx3s  off_sdram_ras(clock <: clock, pin :> sdram_ras, d <:: reg_sdram_ras);
  out1_ff_ulx3s  off_sdram_we (clock <: clock, pin :> sdram_we , d <:: reg_sdram_we );
  out2_ff_ulx3s  off_sdram_dqm(clock <: clock, pin :> sdram_dqm, d <:: reg_sdram_dqm);
  out2_ff_ulx3s  off_sdram_ba (clock <: clock, pin :> sdram_ba , d <:: reg_sdram_ba );
  out13_ff_ulx3s off_sdram_a  (clock <: clock, pin :> sdram_a  , d <:: reg_sdram_a  );

$$else

  inout16_set ioset(
    clock           <:  clock,
    io_pin          <:> sdram_dq,
    io_write        <:  reg_dq_o,
    io_read         :>  dq_i,
    io_write_enable <:  reg_dq_en
  );

$$end
$$end

  uint4  cmd = 7;
  
  uint1   work_todo   = 0;
  uint13  row         = uninitialized;
  uint2   bank        = uninitialized;
  uint10  col         = uninitialized;
  uint512 data        = uninitialized;
  uint1   do_rw       = uninitialized;
  uint8   wmask       = uninitialized;

$$ refresh_cycles      = 750 -- assume 100 MHz
$$ refresh_wait        = 7
$$ cmd_active_delay    = 2
$$ cmd_precharge_delay = 3
$$ print('SDRAM configured for 100 MHz (default), burst length: ' .. read_burst_length)

  int11 refresh_count = -1;
  
  // wait for incount cycles, incount >= 3
  subroutine wait(input uint16 incount)
  {
    // NOTE: waits 3 more than incount
    // +1 for sub entry,
    // +1 for sub exit,
    // +1 for proper loop length
    uint16 count = uninitialized;
    count = incount;
    while (count != 0) {
      count = count - 1;      
    }
  }
  
$$if SIMULATION then
  uint32 cycle = 0;
  error := 0;
$$end        

  sdram_cle := 1;
$$if not ULX3S_IO then
  sdram_cs  := reg_sdram_cs;
  sdram_cas := reg_sdram_cas;
  sdram_ras := reg_sdram_ras;
  sdram_we  := reg_sdram_we;
  sdram_dqm := reg_sdram_dqm;
  sdram_ba  := reg_sdram_ba;
  sdram_a   := reg_sdram_a;
$$if VERILATOR then  
  dq_o      := reg_dq_o;
  dq_en     := reg_dq_en;
$$end  
$$end

  sd.done := 0;
  
  always { // always block tracks in_valid  
    cmd = CMD_NOP;
    (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);
    if (sd.in_valid) {
      // -> copy inputs
      bank      = sd.addr[1, 2]; // bits 1-2
      col       = sd.addr[                      3, $SDRAM_COLUMNS_WIDTH$];
      row       = sd.addr[$SDRAM_COLUMNS_WIDTH+3$, 13];
      wmask     = sd.wmask;
      //byte      = sd.addr[ 0, 1];
      //__display("ADDR %h row: %d col: %d byte: %b bank: %d",sd.addr,row,col,byte,bank);
      data      = sd.data_in;
      do_rw     = sd.rw;    
      // -> signal work to do
      work_todo = 1;
    }
$$if SIMULATION then
   cycle = cycle + 1;
$$end
  }

$$if HARDWARE then
  // wait after powerup
  reg_sdram_a  = 0;
  reg_sdram_ba = 0;
  reg_dq_en    = 0;
  () <- wait <- (65535); // ~0.5 msec at 100MHz
$$end

  // precharge all
  cmd      = CMD_PRECHARGE;
  (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);  
  reg_sdram_a  = {2b0,1b1,10b0};
  () <- wait <- ($cmd_precharge_delay-3$);

  // load mod reg
  cmd      = CMD_LOAD_MODE_REG;
  (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);  
  reg_sdram_ba = 0;
  reg_sdram_a  = {3b000, 1b1/*single write*/, 2b00, 3b011/*CAS*/, 1b0, 3b011 /*burst=8x*/ };
  () <- wait <- (0);
  
  // init done, start answering requests  
  while (1) {

    // refresh?
    if (refresh_count[10,1] == 1) { // became negative!
      //__display("[cycle %d] refresh",cycle);
      // refresh
      cmd           = CMD_REFRESH;
      (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);
      // wait
      () <- wait <- ($refresh_wait-3$);
      // -> reset count
      refresh_count = $refresh_cycles$;  

    } else {

      refresh_count = refresh_count - 1;

      if (work_todo) {
        uint3  stage     = 0;
        uint6  length    = uninitialized;
        uint8  opmodulo  = 8b1;
        uint2  read_bk   = 0;
        uint3  read_br   = 0;
        uint1  reading   = 0;
        //__display("[cycle %d] work_todo: rw:%b",cycle,do_rw);

        work_todo      = 0;
        reg_sdram_a    = row;
        reg_dq_en      = 0;
        // -> activate (pipelined, one for each bank)
        while (~stage[2,1]) {
          //__display("[cycle %d] activate bank: %d row: %d col: %d",cycle,stage,row,col);
          reg_sdram_ba = stage;
          cmd          = CMD_ACTIVE;
          (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);
          stage       = stage + 1;
++: // tRRD
        } // TODO: one cycle wasted here!
        // -> send commands to banks
        stage  = 0;
        length = do_rw
               ? 8 
$$if ULX3S then
               : $4 + 8*4 + 2$;
$$elseif ICARUS then
               : $4 + 8*4 + 1$;
$$else
               : $4 + 8*4 + 0$;
$$end               
        reg_dq_en     = do_rw;
        reg_sdram_a   = {2b0, 1b1/*auto-precharge*/, col};
        while (length != 0) {
          //__display("[cycle %d] length %d -- opmodulo: %b -- data_in: %h",cycle,length,casmodulo,dq_i);
          if (opmodulo[0,1] & ~stage[2,1]) {
$$if SIMULATION then            
            //__display("[cycle %d] send command bank: %d (data %h)",cycle,stage,reg_dq_o);
$$end            
            reg_dq_o      = data[{stage,4b0000},16];
            reg_sdram_ba  = stage;
            reg_sdram_dqm = wmask[{stage,1b0},2];
            opmodulo      = do_rw ? 8b00000010 : 8b10000000;
            stage         = stage + 1;
            cmd           = do_rw ? CMD_WRITE : CMD_READ;
          } else {
            opmodulo = {opmodulo[0,1],opmodulo[1,7]};
          }
          (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);
          sd.data_out[{read_br,read_bk,4b0000},16] = dq_i;
          if (reading) {
            // burst data in
            //__display("######### rw:%d [cycle %d] data in %h read_br:%d read_bk:%d",do_rw,cycle,dq_i,read_br,read_bk);
            read_bk = (read_br == 7) ? read_bk + 1 : read_bk;
            read_br = read_br + 1;
          }
          reading   = reading | (~do_rw & (length == $8*4+1$));
          sd.done   = (do_rw & (stage[0,2] == 2b11)) | (~do_rw & length == 1);
          length    = length - 1;
        }
++: // enforce tRP
// ++:
// ++:

      } // work_todo
    } // refresh

  }
}

// -----------------------------------------------------------
