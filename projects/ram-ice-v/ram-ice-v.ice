// SL 2020-12-02 @sylefeb
//
// RISC-V with RAM IO
// Based on the ice-v
//
// Note: rdinstret and rdcycle are limited to 32 bits
//       rdtime reports cpuid instead of time
//
//
// RV32I cpu, see README.txt
//
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.
// --------------------------------------------------

// bitfields for easier decoding of instructions ; these
// define views on a uint32, that are used upon 
// access, avoiding hard coded values in part-selects
bitfield Itype {
  uint12 imm,
  uint5  rs1,
  uint3  funct3,
  uint5  rd,
  uint7  opcode
}

bitfield Stype {
  uint7  imm11_5,
  uint5  rs2,
  uint5  rs1,
  uint3  funct3,
  uint5  imm4_0,
  uint7  opcode
}

bitfield Rtype {
  uint1  unused_2,
  uint1  select2,
  uint5  unused_1,
  uint5  rs2,
  uint5  rs1,
  uint3  funct3,
  uint5  rd,
  uint7  opcode
}

bitfield Utype {
  uint20  imm31_12,
  uint12  zero
}

bitfield Jtype {
  uint1  imm20,
  uint10 imm10_1,
  uint1  imm11,
  uint8  imm_19_12,
  uint5  rd,
  uint7  opcode
}

bitfield Btype {
  uint1  imm12,
  uint6  imm10_5,
  uint5  rs2,
  uint5  rs1,
  uint3  funct3,
  uint4  imm4_1,
  uint1  imm11,
  uint7  opcode
}

// --------------------------------------------------

// memory 32 bits masked interface
group rv32i_ram_io
{
  uint32  addr       = 0, // 32 bits address space
  uint1   rw         = 0, // rw==1 on write, 0 on read
  uint4   wmask      = 0, // write mask
  uint32  data_in    = 0,
  uint32  data_out   = 0,
  uint1   in_valid   = 0,
  uint1   done       = 0 // pulses when a read or write is done
}

// interface for user
interface rv32i_ram_user {
  output  addr,
  output  rw,
  output  wmask,
  output  data_in,
  output  in_valid,
  input   data_out,
  input   done,
}

// interface for provider
interface rv32i_ram_provider {
  input   addr,
  input   rw,
  input   wmask,
  input   data_in,
  output  data_out,
  input   in_valid,
  output  done
}


// --------------------------------------------------
// The Risc-V RV32I CPU

algorithm rv32i_cpu(
  input uint1    enable,
  input uint26   boot_at,
  input uint3    cpu_id,
  rv32i_ram_user ram
) <autorun> {
  
  // does not have to be simple_dualport_bram, but results in smaller design
  simple_dualport_bram int32 xregsA[32] = {0,pad(uninitialized)};
  simple_dualport_bram int32 xregsB[32] = {0,pad(uninitialized)};
  
  uint1  cmp         = uninitialized;
  uint1  halt        = 0;
  
  uint5  write_rd    = uninitialized;
  uint1  jump        = uninitialized;  
  uint1  branch      = uninitialized;
  
  uint1  load_store  = uninitialized;
  uint1  store       = uninitialized;
  
  uint3  csr         = uninitialized;
  
  uint3  select      = uninitialized;  
  uint1  select2     = uninitialized;
  
  uint2  alu_wait    = 0;

  uint32 instr       = 0;    // initialize with null instruction, which sets everything to 0
  uint26 pc          = uninitialized;
  
  uint26 next_pc   ::= pc + 4; // next_pc tracks the expression 'pc + 4' using the
                               // value of pc from the last clock edge (due to ::)

$$if SIMULATION then  
$$if SHOW_REGS then
$$for i=0,31 do
  int32 xv$i$ = uninitialized;
$$end
$$end
$$end

  int32 imm         = uninitialized;
  uint1 forceZero   = uninitialized;
  uint1 regOrPc     = uninitialized;
  uint1 regOrImm    = uninitialized;
  uint3 loadStoreOp = uninitialized;
  decode dec(
    instr       <: instr,
    write_rd    :> write_rd,
    jump        :> jump,
    branch      :> branch,
    load_store  :> load_store,
    store       :> store,
    loadStoreOp :> loadStoreOp,
    select      :> select,
    select2     :> select2,
    imm         :> imm,
    forceZero   :> forceZero,
    regOrPc     :> regOrPc,
    regOrImm    :> regOrImm,
    csr         :> csr
  );
 
  int32  alu_out     = uninitialized;
  intops alu(
    pc        <:: pc, // <:: since not needed before 1 cycle while decoder works
    xa        <: xregsA.rdata0,
    xb        <: xregsB.rdata0,
    imm       <: imm,
    forceZero <: forceZero,
    regOrPc   <: regOrPc,
    regOrImm  <: regOrImm,
    select    <: select,
    select2   <: select2,
    r         :> alu_out,
  );

  uint3 funct3   ::= Btype(instr).funct3;
  
  uint1  branch_or_jump = uninitialized;
  intcmp cmps(
    a      <:  xregsA.rdata0,
    b      <:  xregsB.rdata0,
    select <:  funct3,
    branch <:  branch,
    jump   <:  jump,
    j      :>  branch_or_jump
  ); 

  uint32 cycle   = 0;
  uint32 instret = 0;

$$if SIMULATION then
  uint64 cycle_last_exec = 0;
$$end

  uint1  ram_done_pulsed = 0;
  
  uint3  case_select     = uninitialized;

  // maintain ram in_valid low (pulses high when needed)
  ram.in_valid   := 0; 
  
  // maintain bram registers
  xregsA.wenable1 := 0;
  xregsB.wenable1 := 0;

  always {
    ram_done_pulsed = ram_done_pulsed | ram.done;
    alu_wait        = (alu_wait != 1 && alu_wait != 0) ? alu_wait - 1 : alu_wait;
    // read/write registers
    xregsA.addr0 = Rtype(instr).rs1;
    xregsB.addr0 = Rtype(instr).rs2;    
    xregsA.addr1 = write_rd;
    xregsB.addr1 = write_rd;
    // produces a case number for each of the three different possibilities:
    // [case 4] a load store completed
    // [case 2] a next instruction is available
    // [case 1] the decode+ALU completed, a next instruction is available
    case_select = {
      enable && ram_done_pulsed && load_store  && alu_wait == 0, // load store completed
      enable && ram_done_pulsed && !load_store && alu_wait == 0, // next instruction available
      enable && ram_done_pulsed && alu_wait == 1                 // decode+ALU done
    };
  } 
  
  // boot
  ram.addr     = boot_at;
  ram.rw       = 0;
  ram.in_valid = 1;
  
  while (!halt) {

    uint1  exec = 0;

    switch (case_select) {
    
      case 4: {
        ram_done_pulsed = 0;
$$if SIMULATION then
        // __display("[load_store done] cycle %d",cycle);
$$end        
        // data with memory access
        if (~store) { 
          // finalize load
          uint32 tmp = uninitialized;
          switch ( loadStoreOp[0,2] ) {
            case 2b00: { // LB / LBU
              tmp = { {24{loadStoreOp[2,1]&ram.data_out[ 7,1]}},ram.data_out[ 0,8]};
            }
            case 2b01: { // LH / LHU
              tmp = { {16{loadStoreOp[2,1]&ram.data_out[15,1]}},ram.data_out[ 0,16]};
            }
            case 2b10: { // LW
              tmp = ram.data_out;  
            }
            default: { tmp = 0; }
          }            
          // __display("[LOAD] %b %h (%h) @%h",loadStoreOp,tmp,ram.data_out,ram.addr);
          // write result to register
          xregsA.wenable1 = write_rd != 0;
          xregsB.wenable1 = write_rd != 0;
          xregsA.wdata1   = tmp;
          xregsB.wdata1   = tmp;
        }
        // prepare load next instruction
        instr           = 0; // resets decoder
        ram.in_valid    = 1;
        ram.rw          = 0;
        ram.addr        = next_pc;
        // __display("[FETCH3] @%h cycle %d",ram.addr,cycle);
      } // case 4

      case 2: {
        ram_done_pulsed = 0;
        // start executing instruction (below)
        pc              = ram.addr;        
        exec            = 1;
        // be optimistic, start reading next
        ram.in_valid    = 1;
        ram.rw          = 0;            
        ram.addr        = pc + 4;
        // __display("[FETCH1] @%h cycle %d",ram.addr,cycle);
      } // case 2

      case 1: {      
        uint26 next_addr = uninitialized;
        uint32 from_csr  = uninitialized;

        ram_done_pulsed = 0;
        alu_wait        = 0;  

$$if SIMULATION then
        __display("========> [ALU done] (cycle %d) select:%b select2:%b branch:%b jump:%b load_store:%b branch_or_jump:%b alu:%h regOrPc:%b regOrImm:%b pc:%h imm:%h",cycle,select,select2,branch,jump,load_store,branch_or_jump,alu_out,regOrPc,regOrImm,pc,imm);
$$end                        
        ram.in_valid    = 1;
        ram.rw          = store;
        exec            = ~(load_store | branch_or_jump);
        pc              = exec ? ram.addr : pc;
        next_addr       = (ram.addr[0,26] + 4);
        ram.addr        = exec
                        ? next_addr // be optimistic, start reading next
                        : alu_out;

        // prepare a potential store
        switch (loadStoreOp) {
          case 3b000: { // SB
              switch (alu_out[0,2]) {
                case 2b00: { ram.data_in[ 0,8] = xregsB.rdata0[ 0,8]; ram.wmask = 4b0001; }
                case 2b01: { ram.data_in[ 8,8] = xregsB.rdata0[ 0,8]; ram.wmask = 4b0010; }
                case 2b10: { ram.data_in[16,8] = xregsB.rdata0[ 0,8]; ram.wmask = 4b0100; }
                case 2b11: { ram.data_in[24,8] = xregsB.rdata0[ 0,8]; ram.wmask = 4b1000; }
              }
          }
          case 3b001: { // SH
              switch (alu_out[1,1]) {
                case 1b0: { ram.data_in[ 0,16] = xregsB.rdata0[ 0,16]; ram.wmask = 4b0011; }
                case 1b1: { ram.data_in[16,16] = xregsB.rdata0[ 0,16]; ram.wmask = 4b1100; }
              }
          }
          case 3b010: { // SW
            ram.data_in = xregsB.rdata0; ram.wmask = 4b1111;
          }
          default: { ram.data_in = 0; }
        }         
        // __display("STORE %b %h [%b] @%h",loadStoreOp,ram.data_in,ram.wmask,ram.addr);            
          
        // store ALU result in registers
        // -> what do we write in register? (pc or alu or csr? -- loads are handled above)
        // csr
        switch (csr[0,2]) {
          case 2b00: { from_csr = cycle;   }
          case 2b01: { from_csr = cpu_id;  }
          case 2b10: { from_csr = instret; }
          default: { }
        }
        // write result to register
        xregsA.wdata1   = csr[2,1] ? from_csr : (branch_or_jump ? (next_pc) : alu_out);
        xregsB.wdata1   = csr[2,1] ? from_csr : (branch_or_jump ? (next_pc) : alu_out);
        xregsA.wenable1 = (write_rd != 0);
        xregsB.wenable1 = (write_rd != 0);
        // __display("[FETCH2] @%h cycle %d",ram.addr,cycle);

        instret         = instret + 1;
        
      } // case 1
      
      default: {}
      
    } // switch
    
    if (exec) {
$$if SIMULATION then    
        __display("[exec] @%h instr = %h [cycle %d (%d since)]",ram.addr,ram.data_out,cycle,cycle - cycle_last_exec);
        cycle_last_exec = cycle;
$$end
        // instruction available, start decode+ALU
        instr        = ram.data_out;
        halt         = (instr == 0);
        // wait for decode+ALU
        alu_wait     = 3; // 1 (tag) + 1 for decode +1 for ALU        
    }
    
    cycle           = cycle + 1;

  } // while

$$if SIMULATION then  
$$if SHOW_REGS then  
++:
  __display("------------------ registers A ------------------");
$$for i=0,31 do
      xregsA.addr0 = $i$;
++:
      xv$i$ = xregsA.rdata0;
$$end
      __display("%h %h %h %h\\n%h %h %h %h\\n%h %h %h %h\\n%h %h %h %h",xv0,xv1,xv2,xv3,xv4,xv5,xv6,xv7,xv8,xv9,xv10,xv11,xv12,xv13,xv14,xv15);
      __display("%h %h %h %h\\n%h %h %h %h\\n%h %h %h %h\\n%h %h %h %h",xv16,xv17,xv18,xv19,xv20,xv21,xv22,xv23,xv24,xv25,xv26,xv27,xv28,xv29,xv30,xv31);
$$end
$$end

}

// --------------------------------------------------
// decode next instruction

algorithm decode(
  input! uint32  instr,
  output uint5   write_rd,
  output uint1   jump,
  output uint1   branch,
  output uint1   load_store,
  output uint1   store,
  output uint3   loadStoreOp,
  output uint3   select,
  output uint1   select2,
  output int32   imm,
  output uint1   forceZero,
  output uint1   regOrPc,
  output uint1   regOrImm,
  output uint3   csr,
) {
  always {
    switch (instr[ 0, 7])
    {    
      case 7b0010111: { // AUIPC
        //__display("AUIPC");
        write_rd    = Rtype(instr).rd;
        jump        = 0;
        branch      = 0;
        load_store  = 0;
        store       = 0;
        select      = 0;
        select2     = 0;           
        imm         = {Utype(instr).imm31_12,12b0};
        forceZero   = 1;
        regOrPc     = 1; // pc
        regOrImm    = 1; // imm
        csr         = 0;
        //__display("AUIPC %x",imm);
      }
      
      case 7b0110111: { // LUI
        //__display("LUI");
        write_rd    = Rtype(instr).rd;
        jump        = 0;
        branch      = 0;
        load_store  = 0;
        store       = 0;
        select      = 0;
        select2     = 0;
        imm         = {Utype(instr).imm31_12,12b0};
        forceZero   = 0; // force x0
        regOrPc     = 0; // reg
        regOrImm    = 1; // imm
        csr         = 0;
      }
      
      case 7b1101111: { // JAL
        //__display("JAL");
        write_rd    = Rtype(instr).rd;
        jump        = 1;
        branch      = 0;
        load_store  = 0;
        store       = 0;
        select      = 0;
        select2     = 0;        
        imm         = {
           {12{Jtype(instr).imm20}},
           Jtype(instr).imm_19_12,
           Jtype(instr).imm11,
           Jtype(instr).imm10_1,
           1b0};
        forceZero   = 1;
        regOrPc     = 1; // pc
        regOrImm    = 1; // imm 
        csr         = 0;        
      }
      
      case 7b1100111: { // JALR
        //__display("JALR");
        write_rd    = Rtype(instr).rd;
        jump        = 1;
        branch      = 0;
        load_store  = 0;
        store       = 0;
        select      = 0;
        select2     = 0;        
        imm         = {{20{instr[31,1]}},Itype(instr).imm};
        forceZero   = 1;
        regOrPc     = 0; // reg
        regOrImm    = 1; // imm
        csr         = 0;        
        //__display("JALR %x",imm);
      }
      
      case 7b1100011: { // branch
        // __display("BR*");
        write_rd    = 0;
        jump        = 0;
        branch      = 1;
        load_store  = 0;
        store       = 0;
        select      = 0;
        select2     = 0;        
        imm         = {
            {20{Btype(instr).imm12}},
            Btype(instr).imm11,
            Btype(instr).imm10_5,
            Btype(instr).imm4_1,
            1b0
            };
        forceZero   = 1;
        regOrPc     = 1; // pc
        regOrImm    = 1; // imm
        csr         = 0;        
      }
 
      case 7b0000011: { // load
        // __display("LOAD");
        write_rd    = Rtype(instr).rd;
        jump        = 0;
        branch      = 0;
        load_store  = 1;
        store       = 0;
        loadStoreOp = Itype(instr).funct3;
        select      = 0;
        select2     = 0;
        imm         = {{20{instr[31,1]}},Itype(instr).imm};
        forceZero   = 1;
        regOrPc     = 0; // reg
        regOrImm    = 1; // imm
        csr         = 0;        
      }
      
      case 7b0100011: { // store
        // __display("STORE");
        write_rd    = 0;
        jump        = 0;
        branch      = 0;
        load_store  = 1;
        store       = 1;
        loadStoreOp = Itype(instr).funct3;
        select      = 0;
        select2     = 0;        
        imm         = {{20{instr[31,1]}},Stype(instr).imm11_5,Stype(instr).imm4_0};
        forceZero   = 1;
        regOrPc     = 0; // reg
        regOrImm    = 1; // imm
        csr         = 0;        
      }

      case 7b0010011: { // integer, immediate  
        write_rd    = Rtype(instr).rd;
        jump        = 0;
        branch      = 0;
        load_store  = 0;
        store       = 0;
        select      = Itype(instr).funct3;
        select2     = instr[30,1] /*SRLI/SRAI*/ & (Itype(instr).funct3 != 3b000) /*not ADD*/;
        imm         = {{20{instr[31,1]}},Itype(instr).imm};        
        forceZero   = 1;
        regOrPc     = 0; // reg
        regOrImm    = 1; // imm
        csr         = 0;        
      }
      
      case 7b0110011: { // integer, registers
        // __display("REGOPS");
        write_rd    = Rtype(instr).rd;
        jump        = 0;
        branch      = 0;
        load_store  = 0;
        store       = 0;
        select      = Itype(instr).funct3;
        select2     = Rtype(instr).select2;
        imm         = 0;        
        forceZero   = 1;
        regOrPc     = 0; // reg
        regOrImm    = 0; // reg
        csr         = 0;        
      }
      
      case 7b1110011: { // timers
        write_rd    = Rtype(instr).rd;
        jump        = 0;
        branch      = 0;
        load_store  = 0;
        store       = 0;
        select      = 0; 
        select2     = 0;
        imm         = 0;
        forceZero   = 1;
        regOrPc     = 0; // reg
        regOrImm    = 0; // reg  
        csr         = {1b1,instr[20,2]};// we grab only the bits for 
        // low bits of rdcycle (0xc00), rdtime (0xc01), instret (0xc02)
      }
      
      default: {
        write_rd    = 0;        
        jump        = 0;
        branch      = 0;
        load_store  = 0;
        store       = 0;    
        select      = 0;
        select2     = 0;
        imm         = 0;
        forceZero   = 0;
        regOrPc     = 0; // reg
        regOrImm    = 0; // reg        
        csr         = 0;        
      }
    }
  }
}

// --------------------------------------------------
// Performs integer computations

algorithm intops(         // input! tells the compiler that the input does not                            
  input!  uint26 pc,      // need to be latched, so we can save registers
  input!  int32  xa,      // caller has to ensure consistency
  input!  int32  xb,
  input!  int32  imm,
  input!  uint3  select,
  input!  uint1  select2,
  input!  uint1  forceZero,
  input!  uint1  regOrPc,
  input!  uint1  regOrImm,
  output! int32  r,
) {
  
  int32 a := regOrPc  ? __signed({6b0,pc[0,26]}) : (forceZero ? xa : __signed(32b0));
  int32 b := regOrImm ? imm : (xb);
  //      ^^
  // using := during a declaration means that the variable now constantly tracks
  // the declared expression (but it is no longer assignable)
  // In other words, this is a wire!
  
  always { // this part of the algorithm is executed every clock  
    switch (select) {
      case 3b000: { // ADD / SUB
        r = a + (select2 ? -b : b);
      }
      case 3b010: { // SLTI
        if (__signed(a) < __signed(b)) { r = 32b1; } else { r = 32b0; }
      }
      case 3b011: { // SLTU
        if (__unsigned(a) < __unsigned(b)) { r = 32b1; } else { r = 32b0; }
      }
      case 3b100: { r = a ^ b;} // XOR
      case 3b110: { r = a | b;} // OR
      case 3b111: { r = a & b;} // AND
      case 3b001: { r = (a <<< b[0,5]); } // SLLI
      case 3b101: { r = select2 ? (a >>> b[0,5]) : (a >> b[0,5]); } // SRLI / SRAI
    }
  }
  
}

// --------------------------------------------------
// Performs integer comparisons

algorithm intcmp(
  input!  int32 a,
  input!  int32 b,
  input!  uint3 select,
  input!  uint1 branch,
  input!  uint1 jump,
  output! uint1 j,
) {
  always {  
    switch (select) {
      case 3b000: { j = jump | (branch & (a == b)); } // BEQ
      case 3b001: { j = jump | (branch & (a != b)); } // BNE
      case 3b100: { j = jump | (branch & (__signed(a)   <  __signed(b)));   } // BLT
      case 3b110: { j = jump | (branch & (__unsigned(a) <  __unsigned(b))); } // BLTU
      case 3b101: { j = jump | (branch & (__signed(a)   >= __signed(b)));   } // BGE
      case 3b111: { j = jump | (branch & (__unsigned(a) >= __unsigned(b))); } // BGEU
      default:    { j = jump; }
    }
  }
}

// --------------------------------------------------
