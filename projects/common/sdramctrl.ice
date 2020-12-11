// -----------------------------------------------------------
// @sylefeb A SDRAM controller in Silice
//
// writes single bytes
// reads bursts of 8 x 16 bits
//
// Expects a 16 bits wide SDRAM interface

// AS4C32M16SB (e.g. some ULX3S)
// 4 banks, 8192 rows, 1024 columns, 16 bits words
// ============== addr ================================
//   25 24 | 23 -------- 11 | 10 ----- 1 | 0
//   bank  |     row        |   column   | byte (H/L)
// ====================================================

// IS42S16160G (e.g. some ULX3S)
// 4 banks, 8192 rows,  512 columns, 16 bits words
// ============== addr ================================
//   25 24 | 22 -------- 10 |  9 ----- 1 | 0
//   bank  |     row        |   column   | byte (H/L)
// ====================================================

// AS4C16M16SA (.e.g some MiSTer SDRAM)
// 4 banks, 8192 rows,  512 columns, 16 bits words
// ============== addr ================================
//   25 24 | 22 -------- 10 |  9 ----- 1 | 0
//   bank  |     row        |   column   | byte (H/L)
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

// SDRAM, raw data exchange (1 byte write, 16 bytes read)
group sdram_raw_io
{
  uint26  addr       = 0,  // addressable bytes (internally deals with 16 bits wide sdram)
  uint1   rw         = 0,
  uint8   data_in    = 0,  //   8 bits write
  uint128 data_out   = 0,  // 128 bits read (8x burst of 16 bits)
  uint1   busy       = 1,
  uint1   in_valid   = 0,
  uint1   out_valid  = 0
}

// SDRAM, byte data exchange
// emulates a simple byte rw interface
// reads are cached (burst length)

group sdram_byte_io
{
  uint26  addr       = 0,  // addressable bytes
  uint1   rw         = 0,
  uint8   data_in    = 0,  // write byte
  uint8   data_out   = 0,  // read byte
  uint1   busy       = 1,
  uint1   in_valid   = 0,
  uint1   out_valid  = 0
}

// => NOTE how sdram_raw_io and sdram_byte_io are compatible in terms of named members
//         this allows using the same interface for both

// Interfaces

// interface for user
interface sdram_user {
  output  addr,
  output  rw,
  output  data_in,
  output  in_valid,
  input   data_out,
  input   busy,
  input   out_valid,
}

// interface for provider
interface sdram_provider {
  input   addr,
  input   rw,
  input   data_in,
  output  data_out,
  output  busy,
  input   in_valid,
  output  out_valid
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

algorithm sdram_controller(
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

  uint1   reg_sdram_cle = uninitialized;
  uint1   reg_sdram_cs  = uninitialized;
  uint1   reg_sdram_cas = uninitialized;
  uint1   reg_sdram_ras = uninitialized;
  uint1   reg_sdram_we  = uninitialized;
  uint2   reg_sdram_dqm = uninitialized;
  uint2   reg_sdram_ba  = uninitialized;
  uint13  reg_sdram_a   = uninitialized;
  uint16  reg_dq_o      = 0;
  uint1   reg_dq_en     = 0;


$$if not VERILATOR then

  uint16 dq_i      = 0;

$$if ULX3S_IO then

  inout16_ff_ulx3s ioset(
    clock           <:  clock,
    io_pin          <:> sdram_dq,
    io_write        <:: reg_dq_o,
    io_read         :>  dq_i,
    io_write_enable <:: reg_dq_en
  );

  out1_ff_ulx3s  off_sdram_cle(clock <: clock, pin :> sdram_cle, d <:: reg_sdram_cle);
  out1_ff_ulx3s  off_sdram_cs (clock <: clock, pin :> sdram_cs , d <:: reg_sdram_cs );
  out1_ff_ulx3s  off_sdram_cas(clock <: clock, pin :> sdram_cas, d <:: reg_sdram_cas);
  out1_ff_ulx3s  off_sdram_ras(clock <: clock, pin :> sdram_ras, d <:: reg_sdram_ras);
  out1_ff_ulx3s  off_sdram_we (clock <: clock, pin :> sdram_we , d <:: reg_sdram_we );
  out2_ff_ulx3s  off_sdram_dqm(clock <: clock, pin :> sdram_dqm, d <:: reg_sdram_dqm);
  out2_ff_ulx3s  off_sdram_ba (clock <: clock, pin :> sdram_ba , d <:: reg_sdram_ba );
  out13_ff_ulx3s off_sdram_a  (clock <: clock, pin :> sdram_a  , d <:: reg_sdram_a  );

$$elseif DE10NANO then

  inout16_set ioset(
    io_pin          <:> sdram_dq,
    io_write        <:  reg_dq_o,
    io_read         :>  dq_i,
    io_write_enable <:  reg_dq_en
  );

$$elseif ICARUS then

$$ error('sdram simulation is currently not working properly with icarus')

$$else

  inout16_set ioset(
    io_pin          <:> sdram_dq,
    io_write        <:  reg_dq_o,
    io_read         :>  dq_i,
    io_write_enable <:  reg_dq_en
  );

$$end
$$end

  uint4  cmd = 7;
  
  uint1  work_done   = 0;

  uint1  work_todo   = 0;
  uint13 row         = 0;
  uint2  bank        = 0;
  uint10 col         = 0;
  uint8  data        = 0;
  uint1  do_rw       = 0;
  uint1  byte        = 0;

$$ refresh_cycles      = 750 -- assume 100 MHz
$$ refresh_wait        = 7
$$ cmd_active_delay    = 2
$$ cmd_precharge_delay = 3
$$ print('SDRAM configured for 100 MHz (default)')

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
  sdram_dqm := reg_sdram_dqm;
  sdram_ba  := reg_sdram_ba;
  sdram_a   := reg_sdram_a;
$$if VERILATOR then  
  dq_o      := reg_dq_o;
  dq_en     := reg_dq_en;
$$end  
$$end

  sd.out_valid := 0;
  
  always { // always block tracks in_valid
  
    cmd = CMD_NOP;
    (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);
    if (sd.in_valid) {
$$if SIMULATION then
      if (sd.busy) {
        error = 1;
        __display("ERROR chip is busy!");
      }    
$$end    
      // -> copy inputs
      bank      = sd.addr[24, 2]; // bits 24-25
      row       = sd.addr[$SDRAM_COLUMNS_WIDTH+1$, 13];
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
  reg_sdram_a  = {3b000, 1b1, 2b00, 3b011/*CAS*/, 1b0, 3b011 /*burst x8*/};
  () <- wait <- (0);

  reg_sdram_ba = 0;
  reg_sdram_a  = 0;
  cmd      = CMD_NOP;
  (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);  
  refresh_count = $refresh_cycles$;
  
  // init done
  work_done     = 1;
  
  while (1) {

    // refresh?
    if (refresh_count == 0) {

      // -> precharge all
      cmd      = CMD_PRECHARGE;
      (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);      
      reg_sdram_a  = {2b0,1b1,10b0};
      () <- wait <- ($cmd_precharge_delay-3$);

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
        work_todo = 0;
        
        // -> activate
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
          reg_dq_o      = {data,data};
          reg_sdram_dqm = {~byte,byte};
          // can accept work
          work_done      = 1;
++:       // wait one cycle to enforce tWR
        } else {
          // read
          cmd         = CMD_READ;
          (reg_sdram_cs,reg_sdram_ras,reg_sdram_cas,reg_sdram_we) = command(cmd);
          reg_dq_en       = 0;
          reg_sdram_dqm   = 2b0;
          reg_sdram_a     = {2b0, 1b1/*auto-precharge*/, col};
          // wait CAS cycles
++:
++:
++:
$$if ULX3S_IO then
++: // dq_i latency
++:
$$end
          // burst 8 x 16 bytes
          {
            uint8 read_cnt = 0;
            while (read_cnt < 8) {
              sd.data_out[{read_cnt,4b0000},16] = dq_i;
              read_cnt      = read_cnt + 1;
              work_done     = (read_cnt[3,1]); // done
              sd.out_valid  = (read_cnt[3,1]); // data_out is available
            }
          }
        }
        
++: // enforce tRP
++:
++:

      } // work_todo
    } // refresh

  }
}

// -----------------------------------------------------------

// Implements a simplified byte memory interface
//
// Assumptions:
//  * !!IMPORTANT!! assumes no writes ever occur into a cached read
//  * busy     == 1 => in_valid  = 0
//  * in_valid == 1 & rw == 1 => in_valid == 0 until out_valid == 1
//
algorithm sdram_byte_readcache(
  sdram_provider sdb,
  sdram_user     sdr,
) <autorun> {

  // cached reads
  uint128 cached         = uninitialized;
  uint26  cached_addr    = 26h3FFFFFF;

  uint2   busy           = 1;
  
  always {

    // maintain busy for one clock to
    // account for one cycle latency
    // of latched outputs to chip
    sdb.busy = busy[0,1];
    if (sdr.busy == 0) {
      busy = {1b0,busy[1,1]};
    }

    if (sdb.in_valid) {
      if (sdb.rw == 0) { // reading
        if (sdb.addr[4,22] == cached_addr[4,22]) {
          // in cache!
          sdb.data_out  = cached >> {sdb.addr[0,4],3b000};
          // -> signal availability
          sdb.out_valid = 1;
          // no request
          sdr.in_valid  = 0;
        } else {
          sdb.busy      = 1;
          busy          = 2b11;
          // record addr to cache
          cached_addr   = sdb.addr;
          // issue read
          sdr.rw        = 0;
          sdr.addr      = {cached_addr[4,22],4b0000};
          sdr.in_valid  = 1;
          // no output
          sdb.out_valid = 0;
        }
      } else { // writing
        sdb.busy      = 1;
        busy          = 2b11;
        // issue write
        sdr.rw        = 1;
        sdr.addr      = sdb.addr;
        sdr.data_in   = sdb.data_in;
        sdr.in_valid  = 1; 
        // no output
        sdb.out_valid = 0;
      }
    } else {
      if (sdr.out_valid) {
        // data is available
        // -> fill cache
        cached        = sdr.data_out;
        // -> extract byte
        sdb.data_out  = cached >> {cached_addr[0,4],3b000};
        // -> signal availability
        sdb.out_valid = 1;
        // no request
        sdr.in_valid = 0;
      } else {
        // no output
        sdb.out_valid = 0;
        // no request
        sdr.in_valid  = 0;
      }
    }

  }

}

// ------------------------- 
// Three-way arbitrer for SDRAM
// sd0 has highest priority, then sd1, then sd2

algorithm sdram_switcher_3way(
  sdram_provider sd0,
  sdram_provider sd1,
  sdram_provider sd2,
  sdram_user     sd
) {
	
  sameas(sd0) buffered_sd0;
  sameas(sd1) buffered_sd1;
  sameas(sd2) buffered_sd2;
  
  uint2 reading   = 2b11;
  uint1 writing   = 0;
  uint3 in_valids = uninitialized;

  sd0.out_valid := 0; // pulses high when ready
  sd1.out_valid := 0; // pulses high when ready
  sd2.out_valid := 0; // pulses high when ready
  sd .in_valid  := 0; // pulses high when ready
  
  always {
    
    in_valids = {buffered_sd2.in_valid , buffered_sd1.in_valid , buffered_sd0.in_valid};

    // buffer requests
    if (buffered_sd0.in_valid == 0 && sd0.in_valid == 1) {
      buffered_sd0.addr       = sd0.addr;
      buffered_sd0.rw         = sd0.rw;
      buffered_sd0.data_in    = sd0.data_in;
      buffered_sd0.in_valid   = 1;
    }
    if (buffered_sd1.in_valid == 0 && sd1.in_valid == 1) {
      buffered_sd1.addr       = sd1.addr;
      buffered_sd1.rw         = sd1.rw;
      buffered_sd1.data_in    = sd1.data_in;
      buffered_sd1.in_valid   = 1;
    }
    if (buffered_sd2.in_valid == 0 && sd2.in_valid == 1) {
      buffered_sd2.addr       = sd2.addr;
      buffered_sd2.rw         = sd2.rw;
      buffered_sd2.data_in    = sd2.data_in;
      buffered_sd2.in_valid   = 1;
    }
    // check if read operations terminated
    switch (reading) {
    case 0 : { 
      if (sd.out_valid == 1) {
        // done
        sd0.data_out  = sd.data_out;
        sd0.out_valid = 1;
        reading       = 2b11;
        buffered_sd0.in_valid = 0;
      }
    }
    case 1 : { 
      if (sd.out_valid == 1) {
        // done
        sd1.data_out  = sd.data_out;
        sd1.out_valid = 1;
        reading       = 2b11;
        buffered_sd1.in_valid = 0;
      }
    }
    case 2 : { 
      if (sd.out_valid == 1) {
        // done
        sd2.data_out  = sd.data_out;
        sd2.out_valid = 1;
        reading       = 2b11;
        buffered_sd2.in_valid = 0;
      }
    }
    default: { 
      if (writing) { // when writing we wait on cycle before resuming, 
        writing = 0; // ensuring the sdram controler reports busy properly
      } else {
        // -> sd0 (highest priority)
        if (   sd.busy == 0
            && in_valids[0,1] == 1) {
          sd.addr     = buffered_sd0.addr;
          sd.rw       = buffered_sd0.rw;
          sd.data_in  = buffered_sd0.data_in;
          sd.in_valid = 1;
          if (buffered_sd0.rw == 0) { 
            reading               = 0; // reading, wait for answer
          } else {
            writing = 1;
            buffered_sd0.in_valid = 0; // done if writing
          }
        }
        if (   sd.busy == 0 
            && in_valids[0,1] == 0 
            && in_valids[1,1] == 1) {
          sd.addr     = buffered_sd1.addr;
          sd.rw       = buffered_sd1.rw;
          sd.data_in  = buffered_sd1.data_in;
          sd.in_valid = 1;        
          if (buffered_sd1.rw == 0) { 
            reading               = 1; // reading, wait for answer
          } else {
            writing = 1;
            buffered_sd1.in_valid = 0; // done if writing
          }
        }
        if (   sd.busy == 0 
            && in_valids[0,1] == 0
            && in_valids[1,1] == 0
            && in_valids[2,1] == 1) {
          sd.addr     = buffered_sd2.addr;
          sd.rw       = buffered_sd2.rw;
          sd.data_in  = buffered_sd2.data_in;
          sd.in_valid = 1;        
          if (buffered_sd2.rw == 0) { 
            reading               = 2; // reading, wait for answer
          } else {
            writing = 1;
            buffered_sd2.in_valid = 0; // done if writing
          }
        } 
      }
    }
    } // switch
    // interfaces are busy while their request is being processed
    sd0.busy = buffered_sd0.in_valid;
    sd1.busy = buffered_sd1.in_valid;
    sd2.busy = buffered_sd2.in_valid;
  } // always
}

// -------------------------
// wrapper for sdram from design running hafl-speed clock
// the wrapper runs full speed, the design using it half-speed
algorithm sdram_half_speed_access(
  sdram_provider sdh,
  sdram_user     sd
) <autorun> {

  sameas(sdh) buffered_sdh;
  
  uint1 reading   = 0;
  uint1 writing   = 0;
  uint1 in_valid  = uninitialized;

  uint1 half_clock = 0;
  uint2 out_valid  = 0;

  sdh.out_valid := 0; // pulses high when ready
  sd .in_valid  := 0; // pulses high when ready
  
  always {
    
    in_valid = buffered_sdh.in_valid;

    // buffer requests
    if (half_clock) { // read only on slow clock
      if (buffered_sdh.in_valid == 0 && sdh.in_valid == 1) {
        buffered_sdh.addr       = sdh.addr;
        buffered_sdh.rw         = sdh.rw;
        buffered_sdh.data_in    = sdh.data_in;
        buffered_sdh.in_valid   = 1;
      }
    }
    // update out_valid
    out_valid = out_valid >> 1;
    // check if read operations terminated
    if (reading) {
      if (sd.out_valid == 1) {
        // done
        sdh.data_out  = sd.data_out;
        out_valid     = 2b11;
        reading       = 0;
        buffered_sdh.in_valid = 0;
      }
    } else { 
      if (writing) { // when writing we wait on cycle before resuming, 
        writing = 0; // ensuring the sdram controler reports busy properly
      } else {
        if (   sd.busy == 0 && in_valid == 1  ) {
          sd.addr     = buffered_sdh.addr;
          sd.rw       = buffered_sdh.rw;
          sd.data_in  = buffered_sdh.data_in;
          sd.in_valid = 1;
          if (buffered_sdh.rw == 0) { 
            reading               = 1; // reading, wait for answer
          } else {
            writing = 1;
            buffered_sdh.in_valid = 0; // done if writing
          }
        }
      }
    } // reading
    // interface is busy while its request is being processed
    sdh.busy      = buffered_sdh.in_valid;
    // two-cycle out valid
    sdh.out_valid = out_valid[0,1];
    // half clock
    half_clock    = ~ half_clock;
  } // always

}

// -----------------------------------------------------------
