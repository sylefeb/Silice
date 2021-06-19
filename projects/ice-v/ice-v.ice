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
// Decoder + ALU
// - decodes instructions
// - performs all integer computations

algorithm ALU(
  input   uint32 instr,     input   uint$addrW$ pc, // instruction and prog. counter
  input   int32  xa,        input   int32  xb, // registers
  input   uint1  trigger,   // pulses high when the ALU should start
  output  uint3  op,        output uint5   write_rd, output uint1   no_rd, 
  output  uint1  jump,      output uint1   load,     output uint1   store,  
  output  uint1  storeAddr, output uint1   storeVal, output int32  val,
  output  int32  n,          // result of next address computation
  output  int32  r,          // result of ALU
  output  uint1  working(0), // are we busy performing integer operations?
) {
  uint5  shamt(0);  
  uint32 cycle(0);

  // decode immediates
  int32 imm_u  <: {instr[12,20],12b0};
  int32 imm_j  <: {{12{instr[31,1]}},instr[12,8],instr[20,1],instr[21,10],1b0};
  int32 imm_i  <: {{20{instr[31,1]}},instr[20,12]};
  int32 imm_b  <: {{20{instr[31,1]}},instr[7,1],instr[25,6],instr[8,4],1b0};
  int32 imm_s  <: {{20{instr[31,1]}},instr[25,7],instr[7,5]};

  // decode opcode
  uint5 opcode   <: instr[ 2, 5];
  uint1 AUIPC    <: opcode == 5b00101;  uint1 LUI    <: opcode == 5b01101;
  uint1 JAL      <: opcode == 5b11011;  uint1 JALR   <: opcode == 5b11001;
  uint1 IntImm   <: opcode == 5b00100;  uint1 IntReg <: opcode == 5b01100;
  uint1 Cycles   <: opcode == 5b11100;  uint1 branch <: opcode == 5b11000;
  uint1 regOrImm <: IntReg  | branch;                    // reg or imm in ALU?
  uint1 pcOrReg  <: AUIPC   | JAL    | branch;           // pc or reg in next addr
  uint1 sub      <: IntReg  & Rtype(instr).sign;         // subtract
  uint1 aluShift <: (IntImm | IntReg) & op[0,2] == 2b01; // shift requested

  // select immediate for the next address computation
  // 'or trick' inspired from femtorv32
  int32 addrImm <:  (AUIPC  ? imm_u : 32b0) | (JAL         ? imm_j : 32b0)
                 |  (branch ? imm_b : 32b0) | ((JALR|load) ? imm_i : 32b0)
                 |  (store  ? imm_s : 32b0);

  // select next address adder first input
  int32 next_addr_a <: pcOrReg ? __signed({20b0,pc[0,$addrW-2$],2b0}) : xa;

  // select ALU and Comparator second input 
  int32 b           <: regOrImm ? (xb) : imm_i;
    
  // trick from femtorv32/swapforth/J1
  // allows to do minus and all comparisons with a single adder
  int33 a_minus_b <: {1b1,~b} + {1b0,xa} + 33b1;
  uint1 a_lt_b    <: (xa[31,1] ^ b[31,1]) ? xa[31,1] : a_minus_b[32,1];
  uint1 a_lt_b_u  <: a_minus_b[32,1];
  uint1 a_eq_b    <: a_minus_b[0,32] == 0;
 
  store        := opcode == 5b01000;  load         := opcode == 5b00000;
  // set decoder outputs depending on incoming instructions
  op           := Rtype(instr).op;
  write_rd     := Rtype(instr).rd;    
  storeAddr    := AUIPC;
  no_rd        := branch  | store  | (Rtype(instr).rd == 5b0); // no write back
  storeVal     := LUI     | Cycles;                  // store value from decoder
  val          := LUI ? imm_u : cycle;               // value from decoder
  cycle        := cycle + 1;                         // increment cycle counter
  
  always {
    int32 shift = uninitialized;
    uint1 j     = uninitialized;

    // ====================== ALU
    // shift (one bit per clock)
    if (working) {
      // decrease shift size
      shamt = shamt - 1;
      // shift one bit
      shift = op[2,1] ? (Rtype(instr).sign ? {r[31,1],r[1,31]} 
                          : {__signed(1b0),r[1,31]}) : {r[0,31],__signed(1b0)};      
    } else {
      // start shifting?
      shamt = ((aluShift & trigger) ? __unsigned(b[0,5]) : 0);
      // store value to be shifted
      shift = xa;
    }
    // are we still shifting?
    working = (shamt != 0);

    // all ALU operations
    switch (op) {
      case 3b000: { r = sub ? a_minus_b : xa + b; }        // ADD / SUB
      case 3b010: { r = a_lt_b; } case 3b011: { r = a_lt_b_u; }// SLTI / SLTU
      case 3b100: { r = xa ^ b;  } case 3b110: { r = xa | b;  }// XOR / OR
      case 3b001: { r = shift;  } case 3b101: { r = shift;    }// SLLI/SRLI/SRAI
      case 3b111: { r = xa & b;  }    // AND
      default:    { r = {32{1bx}}; }  // don't care
    }      

    // ====================== Comparator for branching
    switch (op[1,2]) {
      case 2b00: { j = a_eq_b;  } /*BEQ*/  case 2b10: { j=a_lt_b;} /*BLT*/ 
      case 2b11: { j = a_lt_b_u;} /*BLTU*/ default:   { j = 1bx; }
    }
    jump = (JAL | JALR) | (branch & (j ^ op[0,1]));
    //                                   ^^^^^^^ negates comparator result

    // ====================== Next address adder
    n = next_addr_a + addrImm;

  }
  
}

// --------------------------------------------------
// The Risc-V RV32I CPU itself

algorithm rv32i_cpu(bram_port mem, output! uint$addrW$ wide_addr(0) ) <onehot> {
  //                                           boot address  ^

  // register file, uses two BRAMs to fetch two registers at once
  bram int32 xregsA[32] = {pad(0)}; bram int32 xregsB[32] = {pad(0)};

  // current instruction
  uint32 instr(0);

  // program counter
  uint$addrW$ pc   = uninitialized;  
  uint$addrW$ next_pc <:: pc + 1; // next_pc tracks the expression 'pc + 1'

  // value that has been loaded from memory
  int32 loaded     = uninitialized;

  // all integer operations (ALU + comparisons + next address)
  ALU alu(
    instr <:: instr,         pc <:: pc,
    xa    <:  xregsA.rdata,  xb <: xregsB.rdata,    
  );

  // The 'always_before' block is applied at the start of every cycle.
  // This is a good place to set default values, which also indicates
  // to Silice that some variables (e.g. xregsA.wdata) are fully set
  // every cycle, enabling further optimizations.
  // Default values are overriden from within the algorithm loop.
  always_before {
    // decodes values loaded from memory (used when alu.load == 1)
    uint32 aligned <: mem.rdata >> {alu.n[0,2],3b000};
    switch ( alu.op[0,2] ) { // LB / LBU, LH / LHU, LW
      case 2b00:{ loaded = {{24{(~alu.op[2,1])&aligned[ 7,1]}},aligned[ 0,8]}; }
      case 2b01:{ loaded = {{16{(~alu.op[2,1])&aligned[15,1]}},aligned[ 0,16]};}
      case 2b10:{ loaded = aligned;   }
      default:  { loaded = {32{1bx}}; } // don't care (does not occur)
    }
    // what to write on a store (used when alu.store == 1)
    mem.wdata      = xregsB.rdata << {alu.n[0,2],3b000};
    // maintain write enable low (pulses high when needed)
    mem.wenable    = 4b0000; 
    // maintain alu trigger low
    alu.trigger    = 0;
    // maintain register wenable low
    // (pulsed when necessary)
    xregsA.wenable = 0;
  }

  // the 'always_after' block is executed at the end of every cycle
  always_after { 
    // what do we write in register? (pc, alu or val, load is handled separately)
    int32 write_back <: alu.jump      ? (next_pc<<2) 
                      : alu.storeAddr ? alu.n[0,$addrW+2$]
                      : alu.storeVal  ? alu.val
                      : alu.load      ? loaded
                      : alu.r;
    xregsA.wdata   = write_back;
    xregsB.wdata   = write_back;     
    xregsB.wenable = xregsA.wenable; // xregsB written when xregsA is
    // always write to write_rd, else track instruction register
    xregsA.addr    = xregsA.wenable ? alu.write_rd : Rtype(instr).rs1;
    xregsB.addr    = xregsA.wenable ? alu.write_rd : Rtype(instr).rs2;
    mem.addr       = wide_addr;      // track memory address in interface
  }

  // =========== CPU runs forever
  while (1) {

    // data is now available
    instr       = mem.rdata;
    pc          = wide_addr;

++: // wait for register read (BRAM takes one cycle)

    alu.trigger = 1;

    while (1) { // decode + ALU refresh during the cycle entering the loop

      // this operations loop allows to wait for ALU when needed
      // it is built such that no cycles are wasted    

      // load/store?        
      if (alu.load | alu.store) {   
        // memory address from wich to load/store
        wide_addr = alu.n >> 2;
        // == Store (enabled below if alu.store == 1)
        // build write mask depending on SB, SH, SW
        // assumes aligned, e.g. SW => next_addr[0,2] == 2
        mem.wenable = ({4{alu.store}} & { { 2{alu.op[0,2]==2b10} },
                                              alu.op[0,1] | alu.op[1,1], 1b1 
                                        } ) << alu.n[0,2];

++: // wait for data transaction

        // == Load (enabled below if alu.load == 1)
        // commit result
        xregsA.wenable = ~alu.no_rd;        
        // restore address to program counter
        wide_addr      = next_pc;
        // exit the operations loop
        break;
        //  intruction read from BRAM and write to registers 
        //  occurs as we jump back to loop start

      } else {
        // commit result
        xregsA.wenable = ~alu.no_rd;
        // next instruction address
        wide_addr      = alu.jump ? (alu.n >> 2) : next_pc;
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
