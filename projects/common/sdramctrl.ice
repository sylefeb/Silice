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
  uint1  dq_en = 0;

  inout_set ioset(
    io_pin   <:> sdram_dq,
    io_write <: dq_o,
    io_read  :> dq_i,
    io_write_enable <: dq_en
  );

$$end

  uint4  cmd = 7 (* IOB = "TRUE" *);
  uint1  dqm = 0 (* IOB = "TRUE" *);
  uint2  ba  = 0 (* IOB = "TRUE" *);
  uint13 a   = 0 (* IOB = "TRUE" *);
  
  uint16 delay       = 0;
  uint4  row_open    = 0;
  uint13 row_addr[4] = {0,0,0,0};
  
  uint13 row         = 0;
  uint2  bank        = 0;
  uint8  col         = 0;
  uint32 data        = 0;
  uint1  do_rw       = 0;

$$refresh_cycles = 750
$$refresh_wait   = 6

  uint24 refresh_count = $refresh_cycles$;
  uint1  refresh_asap  = 0;
  
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
  sdram_cle := 1;
 
  cmd       := CMD_NOP;
  out_valid := 0;
 
  busy       = 1;
 
  // init
  $display("init");
  a     = 0;
  ba    = 0;
  dq_en = 0;
  delay = 10100;
  () <- wait <- (delay);
  
  // precharge all
  $display("precharge_all");
  cmd      = CMD_PRECHARGE;
  a[10,1]  = 1;
  ba       = 0;
  row_open = 0;
++:
++:
  
  // refresh 1
  $display("refresh 1");
  cmd     = CMD_REFRESH;
  delay   = $refresh_wait$;
  () <- wait <- (delay);
  
  // refresh 2
  $display("refresh 2");
  cmd     = CMD_REFRESH;
  delay   = $refresh_wait$;
  () <- wait <- (delay);
  
  // load mod reg
  $display("load mode reg");
  cmd     = CMD_LOAD_MODE_REG;
  ba      = 0;
  a       = {3b000, 1b1, 2b00, 3b010, 1b0, 3b010};
  delay   = 2;
  () <- wait <- (delay);

  $display("main loop");

  while (1) {

    // can accept work
    busy     = 0;
    
    // refresh?
    refresh_count = refresh_count - 1;
    if (refresh_count == 0) {
      // -> refresh asap
      refresh_asap  = 1;
    }

    if (in_valid) { // NOTE: works only as long  as
                    // the while loops every cycle.
                    // Otherwise an in_valid pulse could be lost.
                    // A single top level if-else with
                    // nothing after it ensures this.
      // -> now busy!
      busy     = 1;
      // -> copy inputs
      bank     = addr[21,2];
      row      = addr[8,13];
      col      = addr[0,8];
      data     = data_in;
      do_rw    = rw;
      // -> row management
      if (row_open[bank]) {      
        // a row is open
        if (row_addr[bank] == row) {
          // same row: all good!
        } else {
          // different row
          // -> pre-charge
          cmd          = CMD_PRECHARGE;
          a[10,1]      = 0;
          ba           = bank;
          row_open[ba] = 0;
++:
++:          
          // -> activate
          cmd = CMD_ACTIVE;
          ba  = bank;
          a   = row;
          row_open[ba] = 1;
          row_addr[ba] = row;
++:          
        }
      } else {
          // -> activate
          cmd = CMD_ACTIVE;
          ba  = bank;
          a   = row;
          row_open[ba] = 1;
          row_addr[ba] = row;
++:          
      }
      // write or read?
      if (do_rw) {
        // write
        cmd   = CMD_WRITE;
        dq_o  = data;
        dq_en = 1;
        a     = {2b0, 1b0, col, wbyte_addr};
        ba    = bank;
++:
      } else {
        // read
        cmd   = CMD_READ;        
        dq_en = 0;
        a     = {2b0, 1b0, col, 2b0};
        ba    = bank;
        // wait for data
++:
++:
++:
        // burst 4 bytes
        data_out[24,8] = dq_i;
++:        
        data_out[16,8] = dq_i;
++:        
        data_out[8,8]  = dq_i;
++:        
        data_out[0,8]  = dq_i;
        out_valid  = 1;
      }
      
    } else { // no input
    
      // refresh?
      if (refresh_asap) {
        refresh_asap = 0;
        // -> now busy!
        busy     = 1;
        // -> precharge all
        cmd      = CMD_PRECHARGE;
        a[10,1]  = 1;
        ba       = 0;
        row_open = 0;
++:
++:
        // refresh
        cmd      = CMD_REFRESH;
        delay    = $refresh_wait$;
        () <- wait <- (delay);      
        // -> reset count
        refresh_count = $refresh_cycles$;
      }    
      
    }
        
  }
}