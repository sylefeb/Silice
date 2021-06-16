// SL 2020-06-12 @sylefeb
//
// Fun with RISC-V!
// Fits an IceStick
//
// (can be further reduced!)
//
// RV32I cpu, see README.txt
//
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

// Clocks
$$if ICESTICK then
import('../common/icestick_clk_60.v')
$$end
$$if FOMU then
import('../common/fomu_clk_20.v')
$$end

$$config['bram_wmask_byte_wenable_width'] = 'data'

// pre-compilation script, embeds compiled code within a string
$$dofile('pre_include_asm.lua')

// --------------------------------------------------
// SOC
// --------------------------------------------------

algorithm main( // I guess this is the SOC :-D
  output! uint5 leds,
$$if OLED then
  output! uint1 oled_clk,
  output! uint1 oled_mosi,
  output! uint1 oled_dc,
  output! uint1 oled_resn,
  output! uint1 oled_csn,
$$end
  ) <@cpu_clock> {
$$if not SIMULATION then    
  // clock  
$$if ICESTICK then
  icestick_clk_60 clk_gen (
    clock_in  <: clock,
    clock_out :> cpu_clock
  ); 
$$elseif FOMU then
  uint1 cpu_clock  = uninitialized;
  fomu_clk_20 clk_gen (
    clock_in  <: clock,
    clock_out :> cpu_clock
  );   
$$end
$$else
) {
$$end

$$if OLED then
  uint1 displ_en = uninitialized;
  uint1 displ_dta_or_cmd <: mem.wdata[10,1];
  uint8 displ_byte       <: mem.wdata[0,8];
  oled display(
    enable          <: displ_en,
    data_or_command <: displ_dta_or_cmd,
    byte            <: displ_byte,
    oled_din        :> oled_mosi,
    oled_clk        :> oled_clk,
    oled_cs         :> oled_csn,
    oled_dc         :> oled_dc,
  );
$$end

  // ram
  bram uint32 mem<"bram_wmask_byte",input!>[1536] = $meminit$;

  // cpu
  rv32i_cpu cpu( mem <:> mem );

  // io mapping
  always {
$$if OLED then
    displ_en = 0;
$$end
    if (mem.wenable[0,1] & cpu.wide_addr[11,1]) {
      leds = mem.wdata[0,5] & {5{cpu.wide_addr[0,1]}};
      __display("LEDS %b",leds);
$$if OLED then
      // command
      displ_en = (mem.wdata[9,1] | mem.wdata[10,1]) & cpu.wide_addr[1,1];
      // reset
      oled_resn = !(mem.wdata[0,1] & cpu.wide_addr[2,1]);
$$end
    }
  }

  // run the CPU
  () <- cpu <- ();

}

// --------------------------------------------------
// Sends bytes to the OLED screen
// produces a quarter freq clock with one bit traveling a four bit ring
// data is sent one main clock cycle before the OLED clock raises

$$if OLED then

algorithm oled(
  input!  uint1 enable,
  input!  uint1 data_or_command,
  input!  uint8 byte,
  output! uint1 oled_clk,
  output! uint1 oled_din,
  output! uint1 oled_cs,
  output! uint1 oled_dc,
) <autorun> {

  uint2 osc        = 1;
  uint1 dc         = 0;
  uint9 sending    = 0;
  
  oled_cs := 0;
  
  always {
    oled_dc  =  dc;
    osc      =  (sending>1) ? {osc[0,1],osc[1,1]} : 2b1;
    oled_clk =  (sending>1) && (osc[0,1]); // SPI Mode 0
    if (enable) {
      dc         = data_or_command;
      oled_dc    =  dc;
      sending    = {1b1,
        byte[0,1],byte[1,1],byte[2,1],byte[3,1],
        byte[4,1],byte[5,1],byte[6,1],byte[7,1]};
    } else {
      oled_din   = sending[0,1];
      if (osc[0,1]) {
        sending   = {1b0,sending[1,8]};
      }
    }
  }
}

$$end

// --------------------------------------------------
// Processor
// --------------------------------------------------

// bitfield for easier decoding of instructions
// defines a view on a uint32, avoids hard coded values in part-selects
bitfield Rtype { uint1 unused1, uint1 sign, uint5 unused2, uint5 rs2, uint5 rs1,
                 uint3 op,      uint5 rd,   uint7 opcode}

// --------------------------------------------------
// Decoder, decode next instruction

algorithm decoder(
  input   uint32  instr,
  output! uint5   write_rd,   output! uint1   no_rd,
  output! uint1   jump,       output! uint1   branch,
  output! uint1   load_store, output! uint1   store,
  output! uint1   storeAddr,  output! uint3   op,
  output! uint1   aluShift,   output! int32   aluImm,
  output! uint1   sub,        output! uint1   signedShift,
  output! uint1   forceZero,  output! uint1   pcOrReg,
  output! uint1   regOrImm,   output! int32   addrImm,
) {
  // decode immediates
  int32 imm_u  <: {instr[12,20],12b0};
  int32 imm_j  <: {{12{instr[31,1]}},instr[12,8],instr[20,1],instr[21,10],1b0};
  int32 imm_i  <: {{20{instr[31,1]}},instr[20,12]};
  int32 imm_b  <: {{20{instr[31,1]}},instr[7,1],instr[25,6],instr[8,4],1b0};
  int32 imm_s  <: {{20{instr[31,1]}},instr[25,7],instr[7,5]};
  // decode opcode
  uint5 opcode <: instr[ 2, 5];
  // decode all nine instructions
  uint1 AUIPC  <: opcode == 5b00101;  uint1 LUI    <: opcode == 5b01101;
  uint1 JAL    <: opcode == 5b11011;  uint1 JALR   <: opcode == 5b11001;
  uint1 Branch <: opcode == 5b11000;  uint1 Load   <: opcode == 5b00000;
  uint1 Store  <: opcode == 5b01000;  uint1 IntImm <: opcode == 5b00100;
  uint1 IntReg <: opcode == 5b01100;
  // set decoder outputs depending on incoming instructions
  jump         := JAL | JALR;
  branch       := Branch;
  store        := Store;
  load_store   := Load   | Store;
  regOrImm     := IntReg | Branch;
  op           := Rtype(instr).op;
  aluImm       := imm_i;
  sub          := IntReg & Rtype(instr).sign;
  aluShift     := (IntImm | IntReg) & op[0,2] == 2b01;
  signedShift  := Rtype(instr).sign; /*SRLI/SRAI*/
  write_rd     := Rtype(instr).rd;
  no_rd        := Branch | Store | (Rtype(instr).rd == 5b0);
  pcOrReg      := AUIPC | JAL | Branch;
  forceZero    := LUI;
  storeAddr    := LUI | AUIPC;
  // select immediate for the next address computation
  always {
    switch (opcode)
     {
      case 5b00101: { addrImm = imm_u; } // AUIPC
      case 5b01101: { addrImm = imm_u; } // LUI
      case 5b11011: { addrImm = imm_j; } // JAL
      case 5b11000: { addrImm = imm_b; } // branch
      case 5b11001: { addrImm = imm_i; } // JALR
      case 5b00000: { addrImm = imm_i; } // load
      case 5b01000: { addrImm = imm_s; } // store
      default:  { addrImm = {32{1bx}}; } // don't care
     }
  }
}

// --------------------------------------------------
// IntOps: performs all integer computations

algorithm intops(
  input   outputs(decoder) dec, // all outputs of the decoder as inputs
  input   uint12 pc,         input   int32 xa,  input   int32 xb, 
  input   uint1  aluTrigger, // pulses high when the ALU should start
  output  int32  n,          // result of next address computation
  output  int32  r,          // result of ALU
  output  uint1  j,          // result of branch comparisons
  output  uint1  working(0), // are we busy performing integer operations?
) {
  uint5 shamt(0);
  
  // select next address adder inputs
  int32 next_addr_a <:: dec.forceZero ? __signed(32b0) 
                      : (dec.pcOrReg  ? __signed({20b0,pc[0,10],2b0}) 
                      : xa);
  int32 next_addr_b <:: dec.addrImm;

  // select ALU inputs
  int32 a         <: xa;
  int32 b         <: dec.regOrImm ? (xb) : dec.aluImm;
  
  // trick from femtorv32/swapforth/J1
  // allows to do minus and all comparisons with a single adder
  int33 a_minus_b <: {1b1,~b} + {1b0,a} + 33b1;
  uint1 a_lt_b    <: (a[31,1] ^ b[31,1]) ? a[31,1] : a_minus_b[32,1];
  uint1 a_lt_b_u  <: a_minus_b[32,1];
  uint1 a_eq_b    <: a_minus_b[0,32] == 0;

  always {
    uint1 dir(0);
    int32 shift(0);

    // ====================== ALU
    // shift (one bit per clock)
    dir     = dec.op[2,1];
    shamt   = working ? shamt - 1                    // decrease shift counter
                      : ((dec.aluShift & aluTrigger) // start shifting?
                      ? __unsigned(b[0,5]) : 0);
    if (working) {
      // shift one bit
      shift = dir ? (dec.signedShift ? {r[31,1],r[1,31]} 
                  : {__signed(1b0),r[1,31]}) : {r[0,31],__signed(1b0)};      
    } else {
      // store value to be shifted
      shift = a;
    }
    // all ALU operations
    switch (dec.op) {
      case 3b000: { r = dec.sub ? a_minus_b : a + b; } // ADD / SUB
      case 3b010: { r = a_lt_b;                      } // SLTI
      case 3b011: { r = a_lt_b_u;                    } // SLTU
      case 3b100: { r = a ^ b;                       } // XOR
      case 3b110: { r = a | b;                       } // OR
      case 3b111: { r = a & b;                       } // AND
      case 3b001: { r = shift;                       } // SLLI
      case 3b101: { r = shift;                       } // SRLI / SRAI
    }      
    // are we working? (shifting)
    working = (shamt != 0);

    // ====================== Branch comparisons
    switch (dec.op) {
      case 3b000: { j =   a_eq_b;   } // BEQ
      case 3b001: { j = ~ a_eq_b;   } // BNE
      case 3b100: { j =   a_lt_b;   } // BLT
      case 3b110: { j =   a_lt_b_u; } // BLTU
      case 3b101: { j = ~ a_lt_b;   } // BGE
      case 3b111: { j = ~ a_lt_b_u; } // BGEU
      default:    { j = 0; }
    }

    // ====================== Next address adder
    n = next_addr_a + next_addr_b;

  }
  
}

// --------------------------------------------------
// The Risc-V RV32I CPU itself

algorithm rv32i_cpu( bram_port mem, output! uint12 wide_addr(0) ) <onehot> {
  //                                           boot address  ^

  // register file
  //                 |---- indicates we don't want the bram inputs to be latched
  //                 v     writes have to be setup during the same clock cycle
  bram int32 xregsA<input!>[32] = {pad(0)};
  bram int32 xregsB<input!>[32] = {pad(0)};

  // current instruction
  uint32 instr(0);
  // program counter
  uint12 pc        = uninitialized;  
  uint12 next_pc <:: pc+1; // next_pc tracks the expression 'pc + 1' using the
                           // value of pc from the last clock edge (<::)
  // triggers ALU when required
  uint1 aluTrigger = uninitialized;
  // value that has been loaded from memory
  int32 loaded     = uninitialized;

  // decoder
  decoder dec( instr <:: instr );

  // all integer operations (ALU + comparisons + next address)
  intops alu(
    pc          <: pc,            aluTrigger  <: aluTrigger,
    xa          <: xregsA.rdata,  xb          <: xregsB.rdata,
    dec         <: dec
  );

  // the 'always_before' block is executed at the start of every cycle
  always_before {
    // decodes values loaded from memory (correct when needed)
    uint32 aligned <:: mem.rdata >> {alu.n[0,2],3b000};
    switch ( dec.op[0,2] ) {
    case 2b00: { loaded = { {24{(~dec.op[2,1])&aligned[ 7,1]}},aligned[ 0,8]}; } // LB / LBU
    case 2b01: { loaded = { {16{(~dec.op[2,1])&aligned[15,1]}},aligned[ 0,16]};} // LH / LHU
    case 2b10: { loaded = aligned;   } // LW
    default:   { loaded = {32{1bx}}; } // don't care (does not occur)
    }
    // maintain write enable low (pulses high when needed)
    mem.wenable    = 4b0000; 
    // maintain register wenable low
    xregsA.wenable = 0;
    // maintain addr on rs1/rs2 by default (bram is not latched, see input!)
    xregsA.addr    = Rtype(instr).rs1;
    xregsB.addr    = Rtype(instr).rs2;  
    // maintain alu trigger low
    aluTrigger     = 0;
    // what to write on a store (correct when needed)
    mem.wdata      = xregsB.rdata << {alu.n[0,2],3b000};
  }

  // the 'always_after' block is executed at the end of every cycle
  always_after { 
    mem.addr       = wide_addr[0,11]; // track memory address in interface
    xregsB.wdata   = xregsA.wdata;    // xregsB is always paired with xregsA
    xregsB.wenable = xregsA.wenable;  // when writing to registers
  }

  while (1) { // CPU runs forever

    // data is now available
    instr       = mem.rdata;
    pc          = wide_addr;
    // update register immediately
    xregsA.addr = Rtype(instr).rs1;
    xregsB.addr = Rtype(instr).rs2;  

++: // read registers, BRAM takes one cycle

    aluTrigger = 1;

    // decode + ALU occur during the cycle entering the while below
    while (1) {       
      // this operations loop allows to wait for ALU when needed
      // it is built such that no cycles are wasted

      // load/store?        
      if (dec.load_store) {   

        // memory address from wich to load/store
        wide_addr = alu.n >> 2;

        // Store (enabled below if dec.store == 1)
        // build write mask depending on SB, SH, SW
        // assumes aligned, e.g. SW => next_addr[0,2] == 2
        mem.wenable = ({4{dec.store}} & { { 2{dec.op[0,2]==2b10} },
                                          dec.op[0,1] | dec.op[1,1], 1b1 
                                        }) << alu.n[0,2];

++: // wait for data transaction

        // Load (enabled below if no_rd == 0)
        // commit result
        xregsA.wdata   = loaded;
        xregsA.wenable = ~dec.no_rd;
        xregsA.addr    = dec.write_rd;
        xregsB.addr    = dec.write_rd;
        
        // restore address to program counter
        wide_addr = next_pc;
        // exit the operations loop
        break;
        
      } else {

        // shall the CPU jump to a new address?
        uint1 do_jump    <:: dec.jump | (dec.branch & alu.j);
        // what do we write in register? (pc or alu, load is handled above)
        int32 write_back <:: do_jump ? (next_pc<<2) 
                                     : (dec.storeAddr ? alu.n : alu.r);
        // next instruction address
        wide_addr      = do_jump ? (alu.n >> 2) : next_pc;
        // commit result
        xregsA.wdata   = write_back;
        xregsA.wenable = ~dec.no_rd;
        xregsA.addr    = dec.write_rd;
        xregsB.addr    = dec.write_rd;
        // ALU done?
        if (alu.working == 0) { 
          // yes: all is correct, stop here
          break; 
          //  intruction read from BRAM and write to registers 
          //  occurs as we jump back to loop start
        }

      }
    }
  }
}

// --------------------------------------------------
