import('sdram_clock.v')
import('inout_set.v')

/*
    addr is 23 bits
    [22:21] => bank  
    [20:8]  => row
    [7:0]   => column
*/

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
        input   uint23  addr,       // address to read/write
        input   uint2   wbyte_addr, // write byte address with 32-bit word at addr
        input   uint1   rw,         // 1 = write, 0 = read
        input   uint32  data_in,    // data from a read
        output  uint32  data_out,   // data for a write
        output  uint1   busy,       // controller is busy when high
        input   uint1   in_valid,   // pulse high to initiate a read/write
        output  uint1   out_valid   // pulses high when data from read is
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

  inout_set ioset(
    io_pin   <:> sdram_dq,
    io_write <: dq_o,
    io_read  :> dq_i,
    io_write_enable <: dq_en
  );

$$end

  uint4  cmd = 7 (* IOB = "TRUE" *); // attribute for Xilinx synthesis
  uint1  dqm = 0 (* IOB = "TRUE" *); // ensures flip-flop is on io pin
  uint2  ba  = 0 (* IOB = "TRUE" *);
  uint13 a   = 0 (* IOB = "TRUE" *);
  
  uint16 delay       = 0;
  uint4  row_open    = 0;
  uint13 row_addr[4] = {0,0,0,0};

  uint1  work_todo   = 0;  
  uint13 row         = 0;
  uint2  bank        = 0;
  uint8  col         = 0;
  uint32 data        = 0;
  uint1  do_rw       = 0;
  uint2  wbyte       = 0;

$$refresh_cycles = 750
$$refresh_wait   = 7

  uint24 refresh_count = $refresh_cycles$;
  
  // wait for incount cycles, incount >= 3
  subroutine wait(input uint16 incount)
  {
    uint16 count = 0;
    count = incount - 3; // -1 for startup,
                         // -1 for exit,
                         // -1 for proper loop length
    while (count > 0) {
      count = count - 1;      
    }
    return;
  }

  sdram_cs  := cmd[3,1];
  sdram_ras := cmd[2,1];
  sdram_cas := cmd[1,1];
  sdram_we  := cmd[0,1];
  sdram_dqm := dqm;
  sdram_ba  := ba;
  sdram_a   := a;
 
  cmd       := CMD_NOP;

  out_valid := 0;
  
  always { // always block tracks in_valid
  
    if (in_valid) {
      // -> copy inputs
      bank      = addr[21,2]; // 21-22
      row       = addr[8,13]; //  8-20
      col       = addr[0,8];  //  0- 7
      wbyte     = wbyte_addr;
      data      = data_in;
      do_rw     = rw;    
      // -> signal work to do
      work_todo = 1;
      // -> now busy!
      busy      = 1;
    }
  
  }
  
  // start busy during init
  busy       = 1;
 
  // pre-init, wait before enabling clock
  sdram_cle = 0;
  () <- wait <- (10100);
  sdram_cle = 1;

  // init
  a     = 0;
  ba    = 0;
  dq_en = 0;
  delay = 10100;
  () <- wait <- (delay);
  
  // precharge all
  cmd      = CMD_PRECHARGE;
  a[10,1]  = 1;
  ba       = 0;
  row_open = 0;
++:
++:
  
  // refresh 1
  cmd     = CMD_REFRESH;
  delay   = $refresh_wait$;
  () <- wait <- (delay);
  
  // refresh 2
  cmd     = CMD_REFRESH;
  delay   = $refresh_wait$;
  () <- wait <- (delay);
  
  // load mod reg
  cmd     = CMD_LOAD_MODE_REG;
  ba      = 0;
  a       = {3b000, 1b1, 2b00, 3b011, 1b0, 3b010};
  delay   = 3;
  () <- wait <- (delay);

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
        busy     = 1;
        // -> precharge all
        cmd      = CMD_PRECHARGE;
        a        = 0;
        a[10,1]  = 1;
        ba       = 0;
        row_open = 0;
++:
++:
        // refresh
        cmd           = CMD_REFRESH;
        delay         = $refresh_wait$;
        // wait
        () <- wait <- (delay);      
        // could accept work
        busy          = work_todo;
        // -> reset count
        refresh_count = $refresh_cycles$;        
    }

    if (work_todo) {
    // -> row management
      if (row_open[bank,1]) {      
        // a row is open
        if (row_addr[bank] == row) {
          // same row: all good!
        } else {
          // different row
          // -> pre-charge
          cmd            = CMD_PRECHARGE;
          a              = 0;
          ba             = bank;
          row_open[ba,1] = 0; //row closed
++:
++:          
          // -> activate
          cmd = CMD_ACTIVE;
          ba  = bank;
          a   = row;
++:
          // row opened
          row_open[ba,1] = 1; 
          row_addr[ba]   = row;
        }
      } else {
          // -> activate
          cmd = CMD_ACTIVE;
          ba  = bank;
          a   = row;
++:
          // row opened
          row_open[ba,1] = 1;
          row_addr[ba]   = row; 
      }
      // write or read?
      if (do_rw) {
        // write
        cmd   = CMD_WRITE;
        dq_en = 1;
        dq_o  = data[0,8];
        a     = {2b0, 1b0/*no auto-precharge*/, col, wbyte};
        ba    = bank;
++:
        // can accept work
        dq_en          = 0;
        work_todo      = 0;
        busy           = 0;
      } else {
        // read
        dq_en = 0;
        a     = {2b0, 1b0/*no auto-precharge*/, col, 2b0};
        ba    = bank;
        // wait for data (CAS)
        cmd   = CMD_READ;        
++:
++:
++:
++:
        // burst 4 bytes
        data_out[0,8]  = dq_i;
++:        
        data_out[8,8]  = dq_i;
++:        
        data_out[16,8] = dq_i;
++:        
        data_out[24,8] = dq_i;
        out_valid      = 1;
++:
        // can accept work
        work_todo      = 0;
        busy           = 0;
      }
    }
        
  }
}