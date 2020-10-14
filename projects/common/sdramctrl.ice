// -----------------------------------------------------------
// @sylefeb SDRAM simple controller demo
//
// writes single bytes
// reads 32 bits

// AS4C32M16SB (e.g. ULX3S)
// 4 banks, 8192 rows, 1024 columns, 16 bits words
// ============== addr ================================
//   25 24 | 23 -------- 11 | 10 ----- 1 | 0
//   bank  |     row        |   column   | byte (H/L)
// ====================================================

// AS4C16M16SA (.e.g some MiSTer SDRAM)
// 4 banks, 8192 rows,  512 columns, 16 bits words
// ============== addr ================================
//   25 24 | 22 -------- 10 |  9 ----- 1 | 0
//   bank  |     row        |   column   | byte (H/L)
// ====================================================

$$if not SDRAM_COLUMNS_WIDTH then
$$ if ULX3S then
$$   print('setting SDRAM_COLUMNS_WIDTH=10 for ULX3S with AS4C32M16 chip')
$$   SDRAM_COLUMNS_WIDTH = 10
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

// -----------------------------------------------------------

// SDRAM interface, user level
// emulates a simple byte rw interface
// reads are cached (burst length)
//
// IMPORTANT this is specialized to the doomchip
// where no writes ever occur into a cached read!

group sdio
{
  uint26  addr       = 0,  // addressable bytes
  uint1   rw         = 0,
  uint8   data_in    = 0,  // write byte
  uint8   data_out   = 0,  // read byte
  uint1   busy       = 0,
  uint1   in_valid   = 0,
  uint1   out_valid  = 0
}

// SDRAM interface, chip level
//
group sdchipio
{
  uint26  addr       = 0,  // addressable bytes (internally deals with 16 bits wide sdram)
  uint1   rw         = 0,
  uint8   data_in    = 0,  //   8 bits write
  uint128 data_out   = 0,  // 128 bits read (8x burst of 16 bits)
  uint1   busy       = 0,
  uint1   in_valid   = 0,
  uint1   out_valid  = 0
}

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

algorithm sdramctrl_chip(
        // sdram pins
        output  uint1   sdram_cle,
        output  uint1   sdram_cs,
        output  uint1   sdram_cas,
        output  uint1   sdram_ras,
        output  uint1   sdram_we,
        output  uint2   sdram_dqm,
        output  uint2   sdram_ba,
        output  uint13  sdram_a,
        // data bus
$$if VERILATOR then
        input   uint16  dq_i,
        output! uint16  dq_o,
        output! uint1   dq_en,
$$else
        inout   uint16  sdram_dq,
$$end
        // interface
        sdchipio sd {
          input   addr,
          input   rw,
          input   data_in,
          output  data_out,
          output  busy,
          input   in_valid,
          output  out_valid
        }
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

$$if not VERILATOR then

  uint16 dq_i  = 0;
  uint16 dq_o  = 0;
  uint1  dq_en = 0;

  inout16_set ioset(
    io_pin          <:> sdram_dq,
    io_write        <:: dq_o,
    io_read         :>  dq_i,
    io_write_enable <:: dq_en
  );

$$end

  uint4  cmd = 7;
  
  uint1  work_done   = 0;

  uint1  work_todo   = 0;
  uint13 row         = 0;
  uint2  bank        = 0;
  uint10 col         = 0;
  uint32 data        = 0;
  uint1  do_rw       = 0;
  uint1  byte        = 0;

$$ refresh_cycles      = 750 -- assume 100 MHz
$$ refresh_wait        = 7
$$ cmd_active_delay    = 2
$$ cmd_precharge_delay = 3
$$ print('SDRAM configured for 100 MHz (default)')

  uint24 refresh_count = $refresh_cycles$;
  
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
  
  sd.out_valid := 0;
  
  always { // always block tracks in_valid
  
    cmd = CMD_NOP;
    (sdram_cs,sdram_ras,sdram_cas,sdram_we) = command(cmd);
    if (sd.in_valid) {
      if (sd.busy) {
        __display("ERROR chip is busy!");
      }    
      // -> copy inputs
      bank      = sd.addr[24, 2]; // bits 24-25
      row       = sd.addr[$SDRAM_COLUMNS_WIDTH+1$,13];
      col       = sd.addr[                      1, $SDRAM_COLUMNS_WIDTH$];
      byte      = sd.addr[ 0, 1];
      data      = sd.data_in;
      do_rw     = sd.rw;    
      // -> signal work to do
      work_todo = 1;
      // -> signal busy
      sd.busy     = 1;
    }
    if (work_done) {
      work_done = 0;
      sd.busy   = work_todo;
    }
  }
  
  // start busy during init
  sd.busy   = 1;
 
  // pre-init, wait before enabling clock
  sdram_cle = 0;
  () <- wait <- (10100);
  sdram_cle = 1;

  // init
  sdram_a  = 0;
  sdram_ba = 0;
  dq_en    = 0;
  () <- wait <- (10100);
  
  // precharge all
  cmd      = CMD_PRECHARGE;
  (sdram_cs,sdram_ras,sdram_cas,sdram_we) = command(cmd);  
  sdram_a  = {2b0,1b1,10b0};
  () <- wait <- ($cmd_precharge_delay-3$);
  
  // refresh 1
  cmd     = CMD_REFRESH;
  (sdram_cs,sdram_ras,sdram_cas,sdram_we) = command(cmd);  
  () <- wait <- ($refresh_wait-3$);
  
  // refresh 2
  cmd     = CMD_REFRESH;
  (sdram_cs,sdram_ras,sdram_cas,sdram_we) = command(cmd); 
  () <- wait <- ($refresh_wait-3$);
  
  // load mod reg
  cmd      = CMD_LOAD_MODE_REG;
  (sdram_cs,sdram_ras,sdram_cas,sdram_we) = command(cmd);  
  sdram_ba = 0;
  sdram_a  = {3b000, 1b1, 2b00, 3b011/*CAS*/, 1b0, 3b011 /*burst x8*/};
  () <- wait <- (0);

  sdram_ba = 0;
  sdram_a  = 0;
  cmd      = CMD_NOP;
  (sdram_cs,sdram_ras,sdram_cas,sdram_we) = command(cmd);  
  refresh_count = $refresh_cycles$;
  
  // init done
  work_done     = 1;
  
  while (1) {

    // refresh?
    refresh_count = refresh_count - 1;
    if (refresh_count == 0) {
      // -> precharge all
      cmd      = CMD_PRECHARGE;
      (sdram_cs,sdram_ras,sdram_cas,sdram_we) = command(cmd);      
      sdram_a  = {2b0,1b1,10b0};
      () <- wait <- ($cmd_precharge_delay-3$);

      // refresh
      cmd           = CMD_REFRESH;
      (sdram_cs,sdram_ras,sdram_cas,sdram_we) = command(cmd);
      // wait
      () <- wait <- ($refresh_wait-3$);
      // -> reset count
      refresh_count = $refresh_cycles$;        
    }

    if (work_todo) {
      work_todo = 0;
      
      // -> activate
      sdram_ba = bank;
      sdram_a  = row;
      cmd      = CMD_ACTIVE;
      (sdram_cs,sdram_ras,sdram_cas,sdram_we) = command(cmd);
$$for i=1,cmd_active_delay do
++:
$$end
      
      // write or read?
      if (do_rw) {
        // write
        cmd     = CMD_WRITE;
        (sdram_cs,sdram_ras,sdram_cas,sdram_we) = command(cmd);
        dq_en   = 1;
        sdram_a = {2b0, 1b1/*auto-precharge*/, col};
        if (byte) {
          sdram_dqm = 2b01;
          dq_o      = {data[0,8],8b0};
        } else {
          sdram_dqm = 2b10;
          dq_o      = {8b0,data[0,8]};
        }
        // a cycle is spent upon exiting this branch
      } else {
        uint8 read_cnt = 0;
        // read
        cmd         = CMD_READ;
        (sdram_cs,sdram_ras,sdram_cas,sdram_we) = command(cmd);
        dq_en       = 0;
        sdram_dqm   = 2b0;
        sdram_a     = {2b0, 1b1/*auto-precharge*/, col};
        // wait CAS cycles
++:
++:
++:
        // burst 4 bytes
        while (read_cnt < 128) {
          sd.data_out[read_cnt,16] = dq_i;
          read_cnt                 = read_cnt + 16;
        }
      }
      // can accept work
      sdram_dqm      = 2b0;
      dq_en          = 0;
      work_done      = 1;
      sd.out_valid   = 1;
    }
        
  }
}

// -----------------------------------------------------------

// Implements a simplified byte memory interface
//
// Assumptions:
//  * busy     == 1 => in_valid = 0
//  * in_valid == 1 => out_valid = 0
//
algorithm sdramctrl(
  sdio sd {
    input   addr,
    input   rw,
    input   data_in,
    input   in_valid,
    output  data_out,
    output  busy,
    output  out_valid,    
  },
  sdchipio sdchip {
    output  addr,
    output  rw,
    output  data_in,
    output  in_valid,
    input   data_out,
    input   busy,
    input   out_valid,
  },
) <autorun> {

  // cached reads
  uint128 cached      = uninitialized;
  uint26  cached_addr = 26h3FFFFFF;
  uint2   busy        = 1;
  
  always {

    // transfer state from chip
    sdchip.addr     = sd.addr;
    sdchip.rw       = sd.rw;
    sdchip.data_in  = sd.data_in;
    sdchip.in_valid = 0;

    // maintain busy for one clock to
    // account for one cycle latency
    // of latched outputs to chip
    sd.busy         = busy[0,1];
    if (sdchip.busy == 0) {
      busy = {1b0,busy[1,1]};
    }
    
    sd.out_valid = 0;
    if (sdchip.out_valid) {
      // data is available
      // -> fill cache
      cached       = sdchip.data_out;
      // -> extract byte
      sd.data_out  = cached[ {sd.addr[0,3],3b000} , 8 ];
      // -> signal availability
      sd.out_valid = 1;
    } else {
      if (sd.in_valid) {
        if (sd.rw == 0) { // reading
          uint26 read_addr_cached   = uninitialized;
          uint3  read_addr_in_cache = uninitialized;
          read_addr_in_cache        = sd.addr[0,3];
          read_addr_cached          = {sd.addr[3,23],3b000};
          if (read_addr_cached == cached_addr) {
            // in cache!
            sd.data_out  = cached[ {read_addr_in_cache,3b000} , 8 ];
            // -> signal availability
            sd.out_valid = 1;
          } else {
            sd.busy = 1;
            busy    = 2b11;
            // issue read
            sdchip.addr      = read_addr_cached;
            sdchip.in_valid  = 1;
            // record cache addr          
            cached_addr      = read_addr_cached;
          }
        } else { // writting
          sd.busy = 1;
          busy    = 2b11;
          // issue write
          sdchip.in_valid  = 1; 
        }
      }
    }
  
  }

}

// -----------------------------------------------------------
