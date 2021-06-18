// SL 2020-06-12 @sylefeb
//
// Fun with RISC-V!   RV32I cpu, see README.md
//
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

// --------------------------------------------------
// Processor
// --------------------------------------------------

// bitfield for easier decoding of instructions
bitfield Rtype { uint1 unused1, uint1 sign, uint5 unused2, uint5 rs2, 
                 uint5 rs1,     uint3 op,   uint5 rd,      uint7 opcode}

// --------------------------------------------------
// Decoder, decode next instruction
// the use of output! ensures outputs are immediately available to the ALU
// see https://github.com/sylefeb/Silice/blob/master/learn-silice/AlgoInOuts.md

algorithm decoder(
  input   uint32  instr,     output! uint3   op,       output! uint1   sub,       
  output! uint5   write_rd,  output! uint1   no_rd,    output! uint1   jump,       
  output! uint1   branch,    output! uint1   load,     output! uint1   store,      
  output! uint1   storeAddr, output! uint1   storeVal, output! int32   aluImm, 
  output! uint1   regOrImm,  output! uint1   pcOrReg,  output! int32   addrImm, 
  output! int32   val,       output! uint1   negShift, output! uint1   aluShift,
) {
  uint32 cycle(0);
  // decode immediates
  int32 imm_u  <: {instr[12,20],12b0};
  int32 imm_j  <: {{12{instr[31,1]}},instr[12,8],instr[20,1],instr[21,10],1b0};
  int32 imm_i  <: {{20{instr[31,1]}},instr[20,12]};
  int32 imm_b  <: {{20{instr[31,1]}},instr[7,1],instr[25,6],instr[8,4],1b0};
  int32 imm_s  <: {{20{instr[31,1]}},instr[25,7],instr[7,5]};
  // decode opcode
  uint5 opcode <: instr[ 2, 5];
  uint1 AUIPC  <: opcode == 5b00101;  uint1 LUI    <: opcode == 5b01101;
  uint1 JAL    <: opcode == 5b11011;  uint1 JALR   <: opcode == 5b11001;
  uint1 IntImm <: opcode == 5b00100;  uint1 IntReg <: opcode == 5b01100;
  uint1 Cycles <: opcode == 5b11100;  branch       := opcode == 5b11000;
  store        := opcode == 5b01000;  load         := opcode == 5b00000;
  // set decoder outputs depending on incoming instructions
  op           := Rtype(instr).op;    aluImm       := imm_i;
  write_rd     := Rtype(instr).rd;    storeAddr    := AUIPC;
  regOrImm     := IntReg  | branch;                  // reg or imm in ALU?
  sub          := IntReg  & Rtype(instr).sign;       // sub request
  aluShift     := (IntImm | IntReg) & op[0,2] == 2b01; // shift requested
  negShift     := Rtype(instr).sign;                 // SRLI/SRAI
  no_rd        := branch  | store  | (Rtype(instr).rd == 5b0); // no write back
  jump         := JAL     | JALR;                    // should jump
  pcOrReg      := AUIPC   | JAL    | branch;         // pc or reg in next addr
  storeVal     := LUI     | Cycles;                  // store value from decoder
  val          := LUI ? imm_u : cycle;               // value from decoder
  cycle        := cycle + 1;                         // increment cycle counter
  // select immediate for the next address computation 
  addrImm := (AUIPC  ? imm_u : 32b0) | (JAL         ? imm_j : 32b0)
          |  (branch ? imm_b : 32b0) | ((JALR|load) ? imm_i : 32b0)
          |  (store  ? imm_s : 32b0);
}

// --------------------------------------------------
// ALU: performs all integer computations

algorithm ALU(
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
  int32 next_addr_a <: dec.pcOrReg ? __signed({20b0,pc[0,10],2b0}) : xa;
  int32 next_addr_b <: dec.addrImm;

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
    uint1 dir(0); int32 shift(0);

    // ====================== ALU
    // shift (one bit per clock)
    dir     = dec.op[2,1];
    shamt   = working ? shamt - 1                    // decrease shift counter
                      : ((dec.aluShift & aluTrigger) // start shifting?
                      ? __unsigned(b[0,5]) : 0);
    if (working) {
      // shift one bit
      shift = dir ? (dec.negShift ? {r[31,1],r[1,31]} 
                  : {__signed(1b0),r[1,31]}) : {r[0,31],__signed(1b0)};      
    } else {
      // store value to be shifted
      shift = a;
    }
    // all ALU operations
    switch (dec.op) {
      case 3b000: { r = dec.sub ? a_minus_b : a + b; }         // ADD / SUB
      case 3b010: { r = a_lt_b; } case 3b011: { r = a_lt_b_u; }// SLTI / SLTU
      case 3b100: { r = a ^ b;  } case 3b110: { r = a | b;    }// XOR / OR
      case 3b001: { r = shift;  } case 3b101: { r = shift;    }// SLLI/SRLI/SRAI
      case 3b111: { r = a & b;  } // AND
    }      
    // are we working? (shifting)
    working = (shamt != 0);

    // ====================== Branch comparisons
    switch (dec.op) {
      case 3b000: { j =  a_eq_b; } case 3b001: { j = ~a_eq_b;   } // BEQ / BNE
      case 3b100: { j =  a_lt_b; } case 3b110: { j =  a_lt_b_u; } // BLT / BLTU
      case 3b101: { j = ~a_lt_b; } case 3b111: { j = ~a_lt_b_u; } // BGE / BGEU
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

  // register file, uses two BRAMs to fetch two registers at once
  bram int32 xregsA[32] = {pad(0)}; bram int32 xregsB[32] = {pad(0)};

  // current instruction
  uint32 instr(0);

  // program counter
  uint12 pc        = uninitialized;  
  uint12 next_pc <:: pc + 1; // next_pc tracks the expression 'pc + 1' using the
                             // value of pc from the last clock edge (<::)

  // triggers ALU when required
  uint1 aluTrigger = uninitialized;

  // value that has been loaded from memory
  int32 loaded     = uninitialized;

  // decoder
  decoder dec( instr <:: instr );

  // all integer operations (ALU + comparisons + next address)
  ALU alu(
    pc          <: pc,            aluTrigger  <: aluTrigger,
    xa          <: xregsA.rdata,  xb          <: xregsB.rdata,
    dec         <: dec
  );

  // shall the CPU jump to a new address?
  uint1 do_jump    <:: dec.jump | (dec.branch & alu.j);

  // what do we write in register? (pc or alu, load is handled above)
  int32 write_back <::  do_jump       ? (next_pc<<2) 
                     :  dec.storeAddr ? alu.n[0,$addrW$]
                     :  dec.storeVal  ? dec.val
                     :  alu.r;

  // The 'always_before' block is applied at the start of every cycle.
  // This is a good place to set default values, which also indicates
  // to Silice that some variables (e.g. xregsA.wdata) are fully set
  // every cycle, enabling further optimizations.
  // Default values are overriden from within the algorithm loop.
  always_before {
    // decodes values loaded from memory (used when dec.load == 1)
    uint32 aligned <:: mem.rdata >> {alu.n[0,2],3b000};
    switch ( dec.op[0,2] ) { // LB / LBU, LH / LHU, LW
      case 2b00:{ loaded = {{24{(~dec.op[2,1])&aligned[ 7,1]}},aligned[ 0,8]}; }
      case 2b01:{ loaded = {{16{(~dec.op[2,1])&aligned[15,1]}},aligned[ 0,16]};}
      case 2b10:{ loaded = aligned;   }
      default:  { loaded = {32{1bx}}; } // don't care (does not occur)
    }
    // what to write on a store (used when dec.store == 1)
    mem.wdata      = xregsB.rdata << {alu.n[0,2],3b000};
    // maintain write enable low (pulses high when needed)
    mem.wenable    = 4b0000; 
    // maintain alu trigger low
    aluTrigger     = 0;
    // keep reading registers at rs1/rs2 by default
    // so that decoder and ALU see them for multiple cycles
    xregsA.addr    = Rtype(instr).rs1;
    xregsB.addr    = Rtype(instr).rs2;  
    // maintain register wenable low
    // (overriden when necessary)
    xregsA.wenable = 0;
    // by default, write write_back to registers
    // (overriden during a load)
    xregsA.wdata   = write_back;
  }

  // the 'always_after' block is executed at the end of every cycle
  always_after { 
    mem.addr       = wide_addr[0,11]; // track memory address in interface
    xregsB.wdata   = xregsA.wdata;    // xregsB is always paired with xregsA
    xregsB.wenable = xregsA.wenable;  // when writing to registers
  }

  // =========== CPU runs forever
  while (1) {

    // data is now available
    instr       = mem.rdata;
    pc          = wide_addr;
    // update register immediately
    xregsA.addr = Rtype(instr).rs1;
    xregsB.addr = Rtype(instr).rs2;  

++: // wait for register read (BRAM takes one cycle)

    aluTrigger = 1;

    while (1) { // decode + ALU occur during the cycle entering the loop

      // this operations loop allows to wait for ALU when needed
      // it is built such that no cycles are wasted    

      // load/store?        
      if (dec.load | dec.store) {   
        // memory address from wich to load/store
        wide_addr = alu.n >> 2;
        // == Store (enabled below if dec.store == 1)
        // build write mask depending on SB, SH, SW
        // assumes aligned, e.g. SW => next_addr[0,2] == 2
        mem.wenable = ({4{dec.store}} & { { 2{dec.op[0,2]==2b10} },
                                          dec.op[0,1] | dec.op[1,1], 1b1 
                                        }) << alu.n[0,2];

++: // wait for data transaction

        // == Load (enabled below if dec.load == 1)
        // commit result
        xregsA.wdata   = loaded;
        xregsA.wenable = dec.load;
        xregsA.addr    = dec.write_rd;
        xregsB.addr    = dec.write_rd;        
        // restore address to program counter
        wide_addr      = next_pc;
        // exit the operations loop
        break;        
      } else {
        // commit result
        xregsA.wenable = ~dec.no_rd;
        xregsA.addr    = dec.write_rd;
        xregsB.addr    = dec.write_rd;
        // next instruction address
        wide_addr      = do_jump ? (alu.n >> 2) : next_pc;
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
