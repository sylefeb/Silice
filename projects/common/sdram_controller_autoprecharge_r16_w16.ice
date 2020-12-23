// -----------------------------------------------------------
// @sylefeb A SDRAM controller in Silice
//
// SDRAM controller with auto-precharge
// - expects a 16 bits wide SDRAM interface
// - read/writes 16 bits
//
// This is meant as a tutorial controller
//
// For easier compatiblity the input address is in 
// byte addresss but the lower bit is ignored.
//
// Thus accesses must be aligned on 16 bits.
//
// AS4C32M16SB (e.g. some ULX3S)
// 4 banks, 8192 rows, 1024 columns, 16 bits words
// ============== addr ================================
//   25 24 | 23 -------- 11 | 10 ----- 1 | 0
//   bank  |     row        |   column   | byte (ignored)
// ====================================================

// IS42S16160G (e.g. some ULX3S)
// 4 banks, 8192 rows,  512 columns, 16 bits words
// ============== addr ================================
//   25 24 | 22 -------- 10 |  9 ----- 1 | 0
//   bank  |     row        |   column   | byte (ignored)
// ====================================================

// AS4C16M16SA (.e.g some MiSTer SDRAM)
// 4 banks, 8192 rows,  512 columns, 16 bits words
// ============== addr ================================
//   25 24 | 22 -------- 10 |  9 ----- 1 | 0
//   bank  |     row        |   column   | byte (ignored)
// ====================================================

//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

$$if not SDRAM_COLUMNS_WIDTH then
$$ if ULX3S then
$$  -- print('setting SDRAM_COLUMNS_WIDTH=10 for ULX3S with AS4C32M16 chip')
$$  SDRAM_COLUMNS_WIDTH = 9
$$  print('setting SDRAM_COLUMNS_WIDTH=9 for ULX3S with AS4C32M16 or IS42S16160G chip')
$$  print('Note: the AS4C32M16 is only partially used with this setting')
$$ elseif DE10NANO then
$$   print('setting SDRAM_COLUMNS_WIDTH=9 for DE10NANO with AS4C16M16 chip')
$$   SDRAM_COLUMNS_WIDTH =  9
$$ elseif SIMULATION then
$$   print('setting SDRAM_COLUMNS_WIDTH=10 for simulation')
$$   SDRAM_COLUMNS_WIDTH = 10
$$ else
$$   error('SDRAM_COLUMNS_WIDTH not specified')
$$ end
$$end

import('inout16_set.v')

$$if ULX3S then
import('inout16_ff_ulx3s.v')
import('out1_ff_ulx3s.v')
import('out2_ff_ulx3s.v')
import('out13_ff_ulx3s.v')

$$ULX3S_IO = true

$$end

// -----------------------------------------------------------

// this tiny circuitry is repeated every time we need to decompose 
// the command into the pin assignments
circuitry command(
  output sdram_cs,output sdram_ras,output sdram_cas,output sdram_we,input cmd)
{
  sdram_cs  = cmd[3,1];
  sdram_ras = cmd[2,1];
  sdram_cas = cmd[1,1];
  sdram_we  = cmd[0,1];
}

// -----------------------------------------------------------

algorithm sdram_controller_autoprecharge_r16_w16(
        // sdram pins
        // => we use immediate (combinational) outputs as these are registered 
        //    explicitely using dedicqted primitives when available / implemented
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
        sdram_provider sd,
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

  // output pins are all registered
  // pay 1 in latency, gain in reduced delays and stability
  uint1   reg_sdram_cle = uninitialized;
  uint1   reg_sdram_cs  = uninitialized;
  uint1   reg_sdram_cas = uninitialized;
  uint1   reg_sdram_ras = uninitialized;
  uint1   reg_sdram_we  = uninitialized;
  uint2   reg_sdram_ba  = uninitialized;
  uint13  reg_sdram_a   = uninitialized;
  uint16  reg_dq_o      = 0;
  uint1   reg_dq_en     = 0;

$$if not VERILATOR then

  // bus input (data transits in and out through this)
  uint16 dq_i      = 0;
  // Note: the Verilator code path does not use that as Verilator does not support
  //  tri-state instead it uses three pins: dq_i, dq_o and dq_en to emulate the bus

$$if ULX3S_IO then

  // implements a tri-state flip-flop on the output pins
  // this is vendor specific so defined in Verilog (inout16_ff_ulx3s.v)
  // however that is very important for stability
  inout16_ff_ulx3s ioset(
    clock           <:  clock,
    io_pin          <:> sdram_dq,
    io_write        <:: reg_dq_o,
    io_read         :>  dq_i,
    io_write_enable <:: reg_dq_en
  );
  // each pin also gets a special flip-flop on an output
  //                                           vvvvvvv output pin      vvvvv bound variable (tracking value at cycle start)
  out1_ff_ulx3s  off_sdram_cle(clock <: clock, pin :> sdram_cle, d <:: reg_sdram_cle);
  out1_ff_ulx3s  off_sdram_cs (clock <: clock, pin :> sdram_cs , d <:: reg_sdram_cs );
  out1_ff_ulx3s  off_sdram_cas(clock <: clock, pin :> sdram_cas, d <:: reg_sdram_cas);
  out1_ff_ulx3s  off_sdram_ras(clock <: clock, pin :> sdram_ras, d <:: reg_sdram_ras);
  out1_ff_ulx3s  off_sdram_we (clock <: clock, pin :> sdram_we , d <:: reg_sdram_we );
  out2_ff_ulx3s  off_sdram_ba (clock <: clock, pin :> sdram_ba , d <:: reg_sdram_ba );
  out13_ff_ulx3s off_sdram_a  (clock <: clock, pin :> sdram_a  , d <:: reg_sdram_a  );

$$elseif DE10NANO then

  // on the de10nano, using the straightforward approach seems to work just fine
  inout16_set ioset(
    io_pin          <:> sdram_dq,
    io_write        <:  reg_dq_o,
    io_read         :>  dq_i,
    io_write_enable <:  reg_dq_en
  );

$$else

  // simulation (Icarus)
  inout16_set ioset(
    io_pin          <:> sdram_dq,
    io_write        <:  reg_dq_o,
    io_read         :>  dq_i,
    io_write_enable <:  reg_dq_en
  );

$$end
$$end

  uint4  cmd = 7;
  
  uint1  work_todo   = 0;
  uint13 row         = 0;
  uint2  bank        = 0;
  uint10 col         = 0;
  uint16 data        = 0;
  uint1  do_rw       = 0;

$$ refresh_cycles      = 750 -- assume 100 MHz
$$ refresh_wait        = 7
$$ cmd_active_delay    = 2
$$ cmd_precharge_delay = 3
$$ print('SDRAM r16w16 configured for 100 MHz (default)')

  uint10 refresh_count = $refresh_cycles$;
  
  // wait for incount cycles, incount >= 3
  subroutine wait(input uint16 incount)
  {
    // NOTE: waits 3 more than incount
    // +1 for sub entry,
    // +1 for sub exit,
    // +1 for proper loop length
    uint16 count = uninitialized;
    count = incount;
    while (count > 0) {
      count = count - 1;      
    }
  }
  
$$if SIMULATION then        
  error := 0;
$$end        

$$if not ULX3S_IO then
  sdram_cle := reg_sdram_cle;
  sdram_cs  := reg_sdram_cs;
  sdram_cas := reg_sdram_cas;
  sdram_ras := reg_sdram_ras;
  sdram_we  := reg_sdram_we;
  sdram_dqm := 2b00; // dqm (byte mask) is not used in this controller
  sdram_ba  := reg_sdram_ba;
  sdram_a   := reg_sdram_a;
$$if VERILATOR then  
  dq_o      := reg_dq_o;
  dq_en     := reg_dq_en;
$$end  
$$end
  
  always { // always block is executed at every cycle before anything else  
    // keep done low, pulse high when done
    sd.done = 0;
    // defaults to NOP command
    cmd = CMD_NOP;
    (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);
    // track in valid here to ensure we never misss a request
    if (sd.in_valid) {
      // -> copy inputs, decompose the address in bank/row/column
      bank      = sd.addr[24, 2]; // bits 24-25
      row       = sd.addr[$SDRAM_COLUMNS_WIDTH+1$, 13];
      col       = sd.addr[                      1, $SDRAM_COLUMNS_WIDTH$];
      data      = sd.data_in;
      do_rw     = sd.rw;    
      // -> signal work to do
      work_todo = 1;
    }
  }
  
  // pre-init, wait before enabling clock
  reg_sdram_cle = 0;
  () <- wait <- (10100);
  reg_sdram_cle = 1;

  // init
  reg_sdram_a  = 0;
  reg_sdram_ba = 0;
  reg_dq_en    = 0;
  () <- wait <- (10100);
  
  // precharge all
  cmd      = CMD_PRECHARGE;
  (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);  
  reg_sdram_a  = {2b0,1b1,10b0};
  () <- wait <- ($cmd_precharge_delay-3$);
  
  // refresh 1
  cmd     = CMD_REFRESH;
  (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);  
  () <- wait <- ($refresh_wait-3$);
  
  // refresh 2
  cmd     = CMD_REFRESH;
  (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd); 
  () <- wait <- ($refresh_wait-3$);
  
  // load mod reg
  cmd      = CMD_LOAD_MODE_REG;
  (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);  
  reg_sdram_ba = 0;
  reg_sdram_a  = {3b000, 1b1, 2b00, 3b011/*CAS*/, 1b0, 3b000 /*no burst*/};
  () <- wait <- (0);

  reg_sdram_ba = 0;
  reg_sdram_a  = 0;
  cmd      = CMD_NOP;
  (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);  
  refresh_count = $refresh_cycles$;
  
  // init done, start answering requests  
  while (1) {

    // refresh?
    if (refresh_count == 0) {

      // refresh
      cmd           = CMD_REFRESH;
      (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);
      // wait
      () <- wait <- ($refresh_wait-3$);
      // -> reset count
      refresh_count = $refresh_cycles$;  

    } else {

      // decrease refresh count
      refresh_count = refresh_count - 1;

      // any pending request?
      if (work_todo) {
        work_todo = 0;
        
        // first, activate the row of the bank
        reg_sdram_ba = bank;
        reg_sdram_a  = row;
        cmd          = CMD_ACTIVE;
        (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);
$$for i=1,cmd_active_delay do
++:
$$end
        
        // write or read?
        if (do_rw) {
          // __display("<sdram: write %x>",data);
          // write
          cmd       = CMD_WRITE;
          (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);
          reg_dq_en     = 1;
          reg_sdram_a   = {2b0, 1b1/*auto-precharge*/, col};
          reg_dq_o      = data;
          // signal done
          sd.done       = 1;
++:       // wait one cycle to enforce tWR
        } else {
          // read
          cmd         = CMD_READ;
          (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);
          reg_dq_en       = 0;
          reg_sdram_a     = {2b0, 1b1/*auto-precharge*/, col};          
++:       // wait CAS cycles
++:
++:
++:
$$if ULX3S_IO then
++: // dq_i 2 cycles latency due to flip-flops on output and input path
++:
$$end
          // data is available
          sd.data_out = dq_i;
          sd.done     = 1;
        }
        
++: // enforce tRP
++:
++:

      } // work_todo
    } // refresh

  }
}

// -----------------------------------------------------------
