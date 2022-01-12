// SL 2021-07-30 @sylefeb, dual core RV32I cpu, see IceVDual.md, MIT license
bitfield Rtype { uint1 unused1, uint1 sign, uint4 unused2, uint1 muldiv,
                 uint5 rs2,     uint5 rs1,  uint3 op, uint5 rd, uint7 opcode}
algorithm execute( // ================================== execute: decoder + ALU
  input  uint32 instr,    input  uint$addrW$ pc, input int32 xa, input int32 xb,
  input  uint1  trigger,  input  uint1  core_id,   output int32  r,
  output uint3  op,       output uint5  write_rd,  output uint1  no_rd,
  output uint1  jump,     output uint1  load,      output uint1  store,
  output int32  val,      output uint1  storeVal,  output uint1  working(0),
  output uint$addrW+2$ n, output uint1  storeAddr, output uint1  intop) {
  uint5 shamt(0); uint32 cycle(0); // shifter status and cycle counter
  // ==== decode immediates
  int32 imm_u  <: {instr[12,20],12b0};
  int32 imm_j  <: {{12{instr[31,1]}},instr[12,8],instr[20,1],instr[21,10],1b0};
  int32 imm_i  <: {{20{instr[31,1]}},instr[20,12]};
  int32 imm_b  <: {{20{instr[31,1]}},instr[7,1],instr[25,6],instr[8,4],1b0};
  int32 imm_s  <: {{20{instr[31,1]}},instr[25,7],instr[7,5]};
  // ==== decode opcode
  uint5 opcode    <: instr[ 2, 5];
  uint1 AUIPC     <: opcode == 5b00101;  uint1 LUI     <: opcode == 5b01101;
  uint1 JAL       <: opcode == 5b11011;  uint1 JALR    <: opcode == 5b11001;
  uint1 IntImm    <: opcode == 5b00100;  uint1 IntReg  <: opcode == 5b01100;
  uint1 CSR       <: opcode == 5b11100;  uint1 branch  <: opcode == 5b11000;
  uint1 regOrImm  <: IntReg  | branch;   uint1 pcOrReg <: AUIPC | JAL | branch;
  uint1 sub       <: IntReg  & Rtype(instr).sign;         // subtract
  uint1 aluShift  <: (IntImm | IntReg) & op[0,2] == 2b01; // shift requested
  // ==== select inputs
  int$addrW+3$ addr_a <: pcOrReg ? __signed({1b0,pc[0,$addrW-1$],2b0}) : xa;
  int32 b <: regOrImm ? (xb) : imm_i; int32 ra <: xa; int32 rb <: b;
  // ==== allows to do subtraction and all comparisons with a single adder
  int33 a_minus_b <: {1b1,~rb} + {1b0,ra} + 33b1;
  uint1 a_lt_b    <: (ra[31,1] ^ rb[31,1]) ? ra[31,1] : a_minus_b[32,1];
  uint1 a_lt_b_u  <: a_minus_b[32,1]; uint1 a_eq_b <: a_minus_b[0,32] == 0;
  // ==== select immediate for the next address computation
  int$addrW+3$ addr_imm <: (AUIPC? imm_u : 32b0) | ((JALR|load)? imm_i : 32b0)
        | (branch? imm_b : 32b0) | (JAL? imm_j : 32b0) | (store? imm_s : 32b0);
  always { // ==================================== main logic, always active
    uint1 j(0); // temp variables for and comparator
    uint1 shiting <:: (shamt != 0); // are we still shifting?
    load  = opcode == 5b00000;   store     = opcode == 5b01000;
    op    = Rtype(instr).op;     write_rd  = Rtype(instr).rd;
    intop = (IntImm | IntReg);   storeAddr = AUIPC; storeVal = LUI | CSR;
    no_rd = branch  | store  | (Rtype(instr).rd == 5b0);
    val   = LUI ? imm_u : {cycle[0,31],core_id};
    if (trigger) { // shift (one bit per clock)
      r = xa; shamt = aluShift ? __unsigned(b[0,5]) : 0; // start shifting?
    } else { if (shiting) { shamt = shamt - 1;           // decrease shift size
      r = op[2,1] ? (Rtype(instr).sign ? {r[31,1],r[1,31]} // shift 1 bit
                  : {__signed(1b0),r[1,31]}) : {r[0,31],__signed(1b0)};
    } } working = (shamt != 0);
    switch (op) { // all ALU operations
      case 3b000: { r = sub ? a_minus_b : ra + rb; }            // ADD / SUB
      case 3b010: { r = a_lt_b; } case 3b011: { r = a_lt_b_u; } // SLTI / SLTU
      case 3b100: { r = ra ^ rb;} case 3b110: { r = ra | rb;  } // XOR / OR
      case 3b001: { }             case 3b101: { }               // SLLI/SRLI/SRAI
      case 3b111: { r = ra & rb; } default:   { r = {32{1bx}};} }
    switch (op[1,2]) { // comparator for branching
      case 2b00:  { j = a_eq_b;  } /*BEQ */ case 2b10: { j=a_lt_b;} /*BLT*/
      case 2b11:  { j = a_lt_b_u;} /*BLTU*/ default:   { j = 1bx; } }
    jump = (JAL | JALR) | (branch & (j ^ op[0,1])); // comparator result
    n     = addr_a + addr_imm; // next address adder
    cycle = cycle + 1; // increment cycle counter
} }
algorithm rv32i_cpu(bram_port mem) { // ================= dual Risc-V RV32I CPU
  // register files, two BRAMs to fetch two registers at once
  bram int32  rA_0[32]={pad(0)}; bram int32 rB_0[32]={pad(0)};
  bram int32  rA_1[32]={pad(0)}; bram int32 rB_1[32]={pad(0)};
  uint32      instr_0(32h13);  uint32 instr_1(32h13); // current instruction x2
  uint2       stage(3);         // CPU dual stages (see IceVDual.md)
  uint$addrW$ pc_0($Boot-1$);  uint$addrW$ pc_1($Boot-1$);// program counters x2
  uint$addrW$ pc_plus1 <:: (stage[1,1] ? pc_0 : pc_1) + 1;// next program counter
  int32 loaded = uninitialized; // value that has been loaded from memory
  // decoder + ALU, executes the instruction and tells the processor what to do
  uint32 instr <:: (stage[0,1]^stage[1,1]) ? instr_0    : instr_1;
  uint32 pc    <:: (stage[0,1]^stage[1,1]) ? pc_0       : pc_1;
  int32  xa    <:: (stage[0,1]^stage[1,1]) ? rA_0.rdata : rA_1.rdata;
  int32  xb    <:: (stage[0,1]^stage[1,1]) ? rB_0.rdata : rB_1.rdata;
  execute exec(instr <: instr,pc <: pc, xa <: xa, xb <: xb);
  // what do we write in register? (pc, alu, val or load)
  int32 write_back <: (exec.storeAddr ? exec.n[0,$addrW+2$] : 32b0)
   | (exec.intop    ? exec.r  : 32b0) | (exec.jump ? (pc_plus1<<2) : 32b0)
   | (exec.storeVal ? exec.val: 32b0) | (exec.load ? loaded : 32b0);
  always { // always block, done every cycle
    // decodes values loaded from memory (used when exec.load == 1)
    uint32 aligned <: mem.rdata >> {exec.n[0,2],3b000};
    switch ( exec.op[0,2] ) { // LB / LBU, LH / LHU, LW
      case 2b00:{ loaded = {{24{(~exec.op[2,1])&aligned[ 7,1]}},aligned[ 0,8]}; }
      case 2b01:{ loaded = {{16{(~exec.op[2,1])&aligned[15,1]}},aligned[ 0,16]};}
      case 2b10:{ loaded = aligned; } default: { loaded = {32{1bx}}; } }
    // what to write on a store (used when exec.store == 1)
    mem.wdata = (stage[1,1] ? rB_0.rdata : rB_1.rdata) << {exec.n[0,2],3b000};
    // maintain low what pulses when needed
    mem.wenable = 4b0000; exec.trigger = 0; rA_0.wenable = 0; rA_1.wenable = 0;
    // dual state machine, four states: F, T, LS1, LS2/commit
    if ( ~ stage[0,1] ) { // even stage -- one core on F, one core on LS1
      instr_0 = ~stage[1,1] ? mem.rdata : instr_0;         // vvvvvvvvv F
      pc_0    = ~stage[1,1] ? mem.addr  : pc_0;
      instr_1 =  stage[1,1] ? mem.rdata : instr_1;
      pc_1    =  stage[1,1] ? mem.addr  : pc_1;
      mem.addr = ~exec.working ? (exec.n >> 2) : mem.addr; // vvvvvvvvv LS1
      if (exec.store) { // no need to know which core, we only read from exec
        mem.wenable = ( { { 2{exec.op[0,2]==2b10} }, // mask for SB, SH, SW
                          exec.op[0,1] | exec.op[1,1], 1b1
                        } ) << exec.n[0,2]; }
    } else { // stage odd -- one core on T, one core on LS2/commit
      exec.trigger = 1; exec.core_id = stage[1,1];         // vvvvvvvvv T
      rA_0.wenable =  stage[1,1] ? ~exec.no_rd : 0;        // vvvvvvvvv LS2/commit
      rA_1.wenable = ~stage[1,1] ? ~exec.no_rd : 0;
      mem.addr = exec.jump ? (exec.n >> 2) : pc_plus1;  // next instr. fetch
    }
    stage = (exec.working | reset) ? stage : stage + 1; // next state or wait
    // write back data to both register BRAMs
    rA_0.wdata = write_back; rB_0.wdata = write_back; rB_0.wenable=rA_0.wenable;
    rA_1.wdata = write_back; rB_1.wdata = write_back; rB_1.wenable=rA_1.wenable;
    // write to write_rd, else track instruction register
    rA_0.addr = rA_0.wenable ? exec.write_rd : Rtype(instr_0).rs1;
    rB_0.addr = rA_0.wenable ? exec.write_rd : Rtype(instr_0).rs2;
    rA_1.addr = rA_1.wenable ? exec.write_rd : Rtype(instr_1).rs1;
    rB_1.addr = rA_1.wenable ? exec.write_rd : Rtype(instr_1).rs2;
  }
}