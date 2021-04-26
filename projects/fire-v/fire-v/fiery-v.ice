// SL 2020-12-02 @sylefeb
// ------------------------- 
// The Fiery-V core - pipelined RV32I CPU
// 
// Note: rdinstret and rdcycle are limited to 32 bits
//       rdtime reports user_data instead of time
//
// --------------------------------------------------
//
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

$include('risc-v.ice')

// --------------------------------------------------
// The Risc-V RV32I CPU

algorithm rv32i_cpu(
  input uint26   boot_at,
  input uint32   user_data,
  rv32i_ram_user ram,
  output uint26  predicted_addr(0),    // next predicted address
  output uint1   predicted_correct(0), // was the prediction correct?
) <autorun> {
  
  // does not have to be simple_dualport_bram, but results in a smaller design
  simple_dualport_bram int32 xregsA[32] = {0,pad(uninitialized)};
  simple_dualport_bram int32 xregsB[32] = {0,pad(uninitialized)};
  
  uint32 cycle(0);
  uint1  start       = 1;
  uint1  pulse_start = 0;
  uint1  started     = 1;

  always {
    /// CPU pipeline
    // hazards
    uint1 pip_halt(0);
    // F(fetch) stage
    uint32 F_instr(0); // fetched instruction
    uint1  F_instr_valid(0);
    // D(decode) stage
    uint32 D_ALU_A(0);
    uint32 D_ALU_B(0);
    uint26 D_Addr(0);
    uint1  D_jump(0);
    uint1  D_no_rd(0);
    uint1  D_rd_ALU(0);
    uint1  D_rd_CSR(0);
    uint1  D_rd_LUI(0);
    uint1  D_rd_AUIPC(0);
    uint32 D_imm_u(0);
    uint5  D_write_rd(0);
    uint5  H_write_rd(0);
    uint1  H_write_en(0);
    uint1  D_load(0);
    uint1  D_store(0);
    uint1  D_branch(0);
    uint3  D_ALUOp(0);
    uint1  D_ALUSub(0);
    uint1  D_ALUSigned(0);
    uint3  D_LoadStoreOp(0);
    uint2  D_csr_op(0);
    uint26 D_addr(0);
    // A(ALU) stage
    uint26 A_result(0);
    uint1  A_TakeBranch(0);

    uint26 pc(0);
    uint26 pc_p4 <:: pc + 4;


    started = ~ start;
    start   = 0;
  
    // TESTING
    predicted_correct = ~ pulse_start; 
    predicted_addr    = pc_p4;

// __display("[CPU] [cycle %d] ram.done %b pc %h pc_p4 %h",cycle,ram.done,pc,pc_p4);

    {
      // Fetch

      // Hazards:
      // - [F] xregsA.addr1 == Rtype(F_instr).rs1 || xregsA.addr1 == Rtype(F_instr).rs2
      // - [C] write_rd is any register read before...

      // fetching next instruction      
      uint1 fetch_next <: ram.done | pulse_start; 
      // pipeline not halted ^^^^      ^^^^ not already fetching or data just received
      if (ram.done) {
        __display("[F] [cycle %d] received @%h F_instr %h",cycle,ram.addr,ram.data_out);
      }
      ram.in_valid  = predicted_correct; //fetch_next;
      pc            = pulse_start ? 0 : (fetch_next ? pc_p4 : pc);
      ram.addr      = fetch_next  ? pc : ram.addr;
      if (fetch_next) {
        __display("[F] [cycle %d] fetching @%h (pc = @%h)",cycle,ram.addr,pc);
      }
      // receiving next instruction
      F_instr       = ram.data_out;
      F_instr_valid = ram.done;  

      if (F_instr_valid) {
        __display("[F] [cycle %d] regA[%d]? regB[%d]? (reg read setup)",cycle,Rtype(F_instr).rs1,Rtype(F_instr).rs2);
      }
      if (F_instr_valid & H_write_en & (H_write_rd == Rtype(F_instr).rs1 || H_write_rd == Rtype(F_instr).rs2)) {
        // TODO: only if indeed writing!
        __display("[F] [cycle %d] HAZARD register read+write",cycle);
      }

      // setup register read
      xregsA.addr0  = ram.done ? Rtype(F_instr).rs1 : xregsA.addr0;
      xregsB.addr0  = ram.done ? Rtype(F_instr).rs2 : xregsB.addr0;

    } -> {

      // Decoder
      // -> immediates
      int32 imm_u     <:: {Utype(F_instr).imm31_12,12b0};
      int32 imm_j     <:: {{12{Jtype(F_instr).imm20}},Jtype(F_instr).imm_19_12,Jtype(F_instr).imm11,Jtype(F_instr).imm10_1,1b0};
      int32 imm_i     <:: {{20{F_instr[31,1]}},Itype(F_instr).imm};
      int32 imm_b     <:: {{20{Btype(F_instr).imm12}},Btype(F_instr).imm11,Btype(F_instr).imm10_5,Btype(F_instr).imm4_1,1b0};
      int32 imm_s     <:: {{20{F_instr[31,1]}},Stype(F_instr).imm11_5,Stype(F_instr).imm4_0};
      // -> opcodes
      uint5 opcode    <:: F_instr[ 2, 5];  
      uint1 AUIPC     <:: opcode == 5b00101; uint1 LUI    <:: opcode == 5b01101;
      uint1 JAL       <:: opcode == 5b11011; uint1 JALR   <:: opcode == 5b11001;
      uint1 Branch    <:: opcode == 5b11000; uint1 Load   <:: opcode == 5b00000;
      uint1 Store     <:: opcode == 5b01000; uint1 IntImm <:: opcode == 5b00100;
      uint1 IntReg    <:: opcode == 5b01100; uint1 CSR    <:: opcode == 5b11100;      
      // setup for next stages
      D_jump        = (JAL | JALR);          // rd = PC + 4 ; PC = (PC + imm_j)[JAL] | (A + imm_i)[JALR]
      D_branch      = Branch;
      D_no_rd       = (Branch | Store);      //             ; PC = (PC + imm_b)[Branch]
      D_rd_ALU      = (IntImm | IntReg);     // rd = A Op B | A OP imm_i
      D_rd_CSR      = CSR;                   // rd = CSR
      D_rd_LUI      = LUI;                   // rd = imm_u
      D_rd_AUIPC    = AUIPC;                 // rd = PC + imm_u
      D_imm_u       = imm_u;
      D_load        = Load;                  // rd = @( A + imm_i )
      D_store       = Store;                 // @( A + imm_s ) = B
      D_ALUOp       = Itype(F_instr).funct3;
      D_ALUSub      = IntReg & Rtype(F_instr).select2;
      D_ALUSigned   = IntImm & F_instr[30,1]; /*SRLI/SRAI*/
      D_ALU_A       = xregsA.rdata0;
      D_ALU_B       = Store ? imm_s : (IntReg ? xregsB.rdata0 : imm_i);
      D_LoadStoreOp = Itype(F_instr).funct3;
      D_csr_op      = F_instr[20,2]; // low bits of rdcycle (0xc00), rdtime (0xc01), instret (0xc02)      
      D_write_rd    = Rtype(F_instr).rd;
      D_addr        =   pc 
                      + (JAL    ? imm_j 
                      : (Branch ? imm_b
                      :           imm_u));
      if (F_instr_valid) {
        __display("[D] [cycle %d] F_instr: %h opcode: %b",cycle,F_instr,opcode);
        __display("[D]            AUIPC %b JAL %b Branch %b Store %b IntReg %b",AUIPC,JAL,Branch,Store,IntReg);
        __display("[D]            D_addr @%h D_write_rd %d",D_addr,D_write_rd);
        __display("[D]            D_ALU_A %d D_ALU_B %d",D_ALU_A,D_ALU_B);
        __display("[D]            D_no_rd %b D_rd_ALU %b D_rd_CSR %b D_rd_LUI %b",D_no_rd,D_rd_ALU,D_rd_CSR,D_rd_LUI);
      }

    } -> {

      // ALU
      // -> comparator
      switch (D_ALUOp) {
        case 3b000: { A_TakeBranch = D_jump | (D_branch & (D_ALU_A == D_ALU_B)); } // BEQ
        case 3b001: { A_TakeBranch = D_jump | (D_branch & (D_ALU_A != D_ALU_B)); } // BNE
        case 3b100: { A_TakeBranch = D_jump | (D_branch & (__signed(D_ALU_A)   <  __signed(D_ALU_B)));   } // BLT
        case 3b110: { A_TakeBranch = D_jump | (D_branch & (__unsigned(D_ALU_A) <  __unsigned(D_ALU_B))); } // BLTU
        case 3b101: { A_TakeBranch = D_jump | (D_branch & (__signed(D_ALU_A)   >= __signed(D_ALU_B)));   } // BGE
        case 3b111: { A_TakeBranch = D_jump | (D_branch & (__unsigned(D_ALU_A) >= __unsigned(D_ALU_B))); } // BGEU
        default:    { A_TakeBranch = D_jump; }
      }
      // -> arithmetic
      switch (D_ALUOp) {
        case 3b000: { A_result = D_ALU_A + (D_ALUSub ? -D_ALU_B : D_ALU_B); } // ADD / SUB
        case 3b010: { if (__signed(D_ALU_A)   < __signed(D_ALU_B))   { A_result = 32b1; } else { A_result = 32b0; } }   // SLTI
        case 3b011: { if (__unsigned(D_ALU_A) < __unsigned(D_ALU_B)) { A_result = 32b1; } else { A_result = 32b0; } } // SLTU
        case 3b100: { A_result = D_ALU_A ^ D_ALU_B;} // XOR
        case 3b110: { A_result = D_ALU_A | D_ALU_B;} // OR
        case 3b111: { A_result = D_ALU_A & D_ALU_B;} // AND
        case 3b001: { A_result = (D_ALU_A <<< D_ALU_B[0,5]); } // SLLI
        case 3b101: { A_result = D_ALUSigned ? (D_ALU_A >>> D_ALU_B[0,5]) : (D_ALU_A >> D_ALU_B[0,5]); } // SRLI / SRAI
        default:    { A_result = 32b0; }
      }

      if (F_instr_valid) {
        __display("[A] [cycle %d] D_ALUOp: %b D_ALU_A: %d D_ALU_B: %d A_result = %d",cycle,D_ALUOp,__signed(D_ALU_A),__signed(D_ALU_B),__signed(A_result));
      }

    } -> {

      // Load-Store


      // Register write hazard detection
      H_write_en = F_instr_valid & ~D_no_rd & (D_write_rd != 0);
      H_write_rd = D_write_rd;

    } -> {

      // Commit

      uint32 rd_value <::   D_rd_ALU   ? A_result 
                        : ( D_jump     ? pc_p4
                        : ( D_rd_LUI   ? D_imm_u
                        : ( D_rd_AUIPC ? D_addr
                        : ( /*D_rd_CSR   ?*/ cycle
                        // D_load
                        ))));

      if (F_instr_valid) {
        __display("[C] [cycle %d] D_no_rd %b D_rd_ALU %d D_jump %d D_rd_LUI %b D_rd_AUIPC %b D_rd_CSR %b ",cycle,
              D_no_rd,D_rd_ALU,D_jump,D_rd_LUI,D_rd_AUIPC,D_rd_CSR);
        __display("[C] retiring %h",F_instr);
        __display("[C] reg[%d] = %d",D_write_rd,__signed(A_result));
      }

      //////////////// TODO write hazard!

      // write back
      xregsA.wenable1 = H_write_en;
      xregsB.wenable1 = H_write_en;
      xregsA.addr1    = D_write_rd;
      xregsB.addr1    = D_write_rd;
      xregsA.wdata1   = rd_value;
      xregsB.wdata1   = rd_value;
      
    }
        
    pulse_start = ~ start & ~ started;
    cycle       = cycle + 1;

  } // always

}


// --------------------------------------------------
