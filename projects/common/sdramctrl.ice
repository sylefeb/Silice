import('sdram_clock.v')
import('inout8_set.v')

/*
    addr is 23 bits
    [22:21] => bank  
    [20:8]  => row
    [7:0]   => column
*/

// SDRAM interface
group sdio
{
  uint23 addr = 0,
  uint2  wbyte_addr = 0,
  uint1  rw = 0,
  uint32 data_in = 0,
  uint32 data_out = 0,
  uint1  busy = 0,
  uint1  in_valid = 0,
  uint1  out_valid = 0
}

algorithm sdramctrl(
        input   uint1   clk,
        input   uint1   rst,
        // sdram pins
        output! uint1   sdram_clk,
        output! uint1   sdram_cle,
        output! uint1   sdram_cs,
        output! uint1   sdram_cas,
        output! uint1   sdram_ras,
        output! uint1   sdram_we,
        output! uint1   sdram_dqm,
        output! uint2   sdram_ba,
        output! uint13  sdram_a,
        // data bus
$$if VERILATOR then
        input   uint8   dq_i,
        output! uint8   dq_o,
        output! uint1   dq_en,
$$else
        inout   uint8   sdram_dq,
$$end
        // interface
        sdio sd {
          input   addr,       // address to read/write
          input   wbyte_addr, // write byte address within 32-bit word at addr
          input   rw,         // 1 = write, 0 = read
          input   data_in,    // data from a read
          output  data_out,   // data for a write
          output  busy,       // controller is busy when high
          input   in_valid,   // pulse high to initiate a read/write
          output  out_valid   // pulses high when data from read is
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

  sdram_clock sdclock(
    clk       <: clk,
    sdram_clk :> sdram_clk
  );

$$if not VERILATOR then

  uint8  dq_i  = 0 (* IOB = "TRUE" *);
  uint8  dq_o  = 0 (* IOB = "TRUE" *);
  uint1  dq_en = 0 (* IOB = "TRUE" *);

  inout8_set ioset(
    io_pin          <:> sdram_dq,
    io_write        <:: dq_o,
    io_read         :>  dq_i,
    io_write_enable <:: dq_en
  );

$$end

  uint4  cmd = 7 (* IOB = "TRUE" *); // attribute for Xilinx synthesis
  uint1  dqm = 0 (* IOB = "TRUE" *); // ensures flip-flop is on io pin
  uint2  ba  = 0 (* IOB = "TRUE" *);
  uint13 a   = 0 (* IOB = "TRUE" *);
  
  uint4  row_open    = 0;
  uint13 row_addr[4] = {0,0,0,0};

  uint1  work_todo   = 0;  
  uint13 row         = 0;
  uint2  bank        = 0;
  uint8  col         = 0;
  uint32 data        = 0;
  uint1  do_rw       = 0;
  uint2  wbyte       = 0;

$$if not sdramctrl_clock_freq then
$$  refresh_cycles      = 750 -- assume 100 MHz
$$  refresh_wait        = 7
$$  read_wait           = 3
$$  cmd_active_delay    = 1
$$  cmd_precharge_delay = 2
$$  print('SDRAM configured for 100 MHz (default)')
$$else
$$  refresh_cycles      = math.floor(750*sdramctrl_clock_freq/100)
$$  refresh_wait        = 1 + math.floor(7*sdramctrl_clock_freq/100)
$$  read_wait           = 1 + math.floor(math.max(4, 4*sdramctrl_clock_freq/100))
$$  cmd_active_delay    = 1
$$  cmd_precharge_delay = 2
$$  if sdramctrl_clock_freq > 100 then
$$    cmd_active_delay        = 2
$$    cmd_precharge_delay     = 4
$$  end
$$  print('SDRAM configured for ' .. sdramctrl_clock_freq .. ' MHz')
$$end

  uint24 refresh_count = $refresh_cycles$;
  
  // wait for incount cycles, incount >= 3
  subroutine wait(input uint16 incount)
  {
    uint16 count = 0;
    count = incount - 3; // -1 for sub entry,
                         // -1 for sub exit,
                         // -1 for proper loop length
    while (count > 0) {
      count = count - 1;      
    }
  }

  subroutine precharge(
     reads  CMD_PRECHARGE,
     writes cmd,writes a,writes ba,
     readwrites  row_open,
     input uint2 bk,
     input uint1 all)
  {
        cmd      = CMD_PRECHARGE;
        a        = 0;
        a[10,1]  = all;
        ba       = bk;
        if (all) {
          row_open = 0;
        } else {
          row_open[bk,1] = 0;
        }
$$for i=1,cmd_precharge_delay-1 do         
++:
$$end
  }
  
  subroutine activate(
    reads CMD_ACTIVE, writes cmd, writes ba, writes a,
    input uint2 bk,input uint13 rw)
  {
    // -> activate
    cmd = CMD_ACTIVE;
    ba  = bk;
    a   = rw;
$$for i=1,cmd_active_delay do
++:
$$end  
  }
  
  sdram_cs  := cmd[3,1];
  sdram_ras := cmd[2,1];
  sdram_cas := cmd[1,1];
  sdram_we  := cmd[0,1];
  sdram_dqm := dqm;
  sdram_ba  := ba;
  sdram_a   := a;
 
  cmd       := CMD_NOP;

  sd.out_valid := 0;
  
  always { // always block tracks in_valid
  
    if (sd.in_valid) {
      // -> copy inputs
      bank      = sd.addr[21,2]; // 21-22
      row       = sd.addr[8,13]; //  8-20
      col       = sd.addr[0,8];  //  0- 7
      wbyte     = sd.wbyte_addr;
      data      = sd.data_in;
      do_rw     = sd.rw;    
      // -> signal work to do
      work_todo = 1;
      // -> now busy!
      sd.busy   = 1;
    }
  
  }
  
  // start busy during init
  sd.busy   = 1;
 
  // pre-init, wait before enabling clock
  sdram_cle = 0;
  () <- wait <- (10100);
  sdram_cle = 1;

  // init
  a     = 0;
  ba    = 0;
  dq_en = 0;
  () <- wait <- (10100);
  
  // precharge all
  () <- precharge <- (0,1);
  
  // refresh 1
  cmd     = CMD_REFRESH;
  () <- wait <- ($refresh_wait$);
  
  // refresh 2
  cmd     = CMD_REFRESH;
  () <- wait <- ($refresh_wait$);
  
  // load mod reg
  cmd     = CMD_LOAD_MODE_REG;
  ba      = 0;
  a       = {3b000, 1b1, 2b00, 3b011, 1b0, 3b010};
  () <- wait <- (3);

  ba            = 0;
  a             = 0;
  cmd           = CMD_NOP;
  row_open      = 0;
  refresh_count = $refresh_cycles$;
  
  while (1) {

    // refresh?
    refresh_count = refresh_count - 1;
    if (refresh_count == 0) {
        // -> now busy!
        sd.busy  = 1;
        // -> precharge all
        () <- precharge <- (0,1);
        // refresh
        cmd           = CMD_REFRESH;
        // wait
        () <- wait <- ($refresh_wait$);      
        // could accept work
        sd.busy       = work_todo;
        // -> reset count
        refresh_count = $refresh_cycles$;        
    }

    if (work_todo) {
      // -> row management
      if (!row_open[bank,1] || row_addr[bank] != row) {
        if (row_open[bank,1]) {
          // different row open
          // -> pre-charge
          () <- precharge <- (bank,0);
        }
        // -> activate
        () <- activate <- (bank,row);
      }
      // row opened
      row_open[ba,1] = 1; 
      row_addr[ba]   = row;      
      // write or read?
      if (do_rw) {
        // write
        cmd   = CMD_WRITE;
        dq_en = 1;
        a     = {2b0, 1b0/*no auto-precharge*/, col, wbyte};
        ba    = bank;
        dq_o  = data[0,8];
        // a cycle is spent upon exiting this branch
      } else {
        uint6 read_cnt = 0;
        // read
        cmd   = CMD_READ;
        dq_en = 0;
        a     = {2b0, 1b0/*no auto-precharge*/, col, 2b0};
        ba    = bank;
++:
++:
// the third comes when entering the while
        // burst 4 bytes
        while (read_cnt < 32) {
          sd.data_out[read_cnt,8] = dq_i;
          read_cnt                = read_cnt + 8;
        }
      }
      // can accept work
      dq_en          = 0;
      work_todo      = 0;
      sd.busy        = 0;
      sd.out_valid   = 1;
    }
        
  }
}