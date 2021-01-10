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
  uint1  halt(0);
  
  uint5  write_rd    = uninitialized;
  uint1  jump        = uninitialized;  
  uint1  branch      = uninitialized;
   
  uint3  csr         = uninitialized;
  
  uint3  select      = uninitialized;  
  uint1  select2     = uninitialized;
  
  
  uint32 instr(0);    // initialize with null instruction, which sets everything to 0
  uint26 pc            = uninitialized;
  uint32 next_instr(0);
  uint26 next_instr_pc = uninitialized;
  
  uint26 next_pc     = uninitialized;
  
$$if SIMULATION then  
$$if SHOW_REGS then
$$for i=0,31 do
  int32 xv$i$ = uninitialized;
$$end
$$end
$$end

  int32 imm         = uninitialized;
  uint1 pcOrReg     = uninitialized;
  uint1 regOrImm    = uninitialized;
  
  uint1 load_store  = uninitialized;
  uint1 store       = uninitialized;
  uint3 loadStoreOp = uninitialized;
  uint1 rd_enable   = uninitialized;
  
  uint1 saved_store       = uninitialized;
  uint3 saved_loadStoreOp = uninitialized;
  uint1 saved_rd_enable   = uninitialized;
  
  uint32 refetch_addr = uninitialized;
  uint1  refetch_rw   = uninitialized;
  
  int32 aluA        = uninitialized;
  int32 aluB        = uninitialized;
  int32 regA        = uninitialized;
  int32 regB        = uninitialized;
  
  decode dec(
    instr       <: instr,
    pc          <: pc,
    regA        <: regA,
    regB        <: regB,
    next_pc     :> next_pc,
    write_rd    :> write_rd,
    jump        :> jump,
    branch      :> branch,
    load_store  :> load_store,
    store       :> store,
    loadStoreOp :> loadStoreOp,
    select      :> select,
    select2     :> select2,
    imm         :> imm,
    pcOrReg     :> pcOrReg,
    regOrImm    :> regOrImm,
    csr         :> csr,
    rd_enable   :> rd_enable,
    aluA        :> aluA,
    aluB        :> aluB,
  );
 
  int32  alu_out     = uninitialized;
  intops alu(
    pc        <:: pc,
    xa        <: aluA,
    xb        <: aluB,
    imm       <: imm,
    pcOrReg   <: pcOrReg,
    regOrImm  <: regOrImm,
    select    <: select,
    select2   <: select2,
    r         :> alu_out,
  );

  uint3 funct3   ::= Btype(instr).funct3;
  
  uint1  branch_or_jump = uninitialized;
  intcmp cmps(
    a      <:  aluA,
    b      <:  aluB,
    select <:  funct3,
    branch <:  branch,
    jump   <:  jump,
    j      :>  branch_or_jump
  ); 

  uint32 cycle(0);
  uint32 instret(0);

$$if SIMULATION then
  uint64 cycle_last_retired(0);
$$end

  uint1  ram_done_pulsed(0);
  uint1  wait_next_instr(1);
  uint1  commit_decode(0);

  uint1  do_load_store(0);

  uint1  refetch(0);  
  
  uint4  case_select   = uninitialized;

  // maintain ram in_valid low (pulses high when needed)
  ram.in_valid    := 0; 
  
  // maintain bram registers
  xregsA.wenable1 := 0;
  xregsB.wenable1 := 0;

  always {
  
    ram_done_pulsed = ram_done_pulsed | ram.done;
        
    case_select = {
                    refetch        & ram_done_pulsed,
                   ~refetch        & do_load_store   & ram_done_pulsed, // performing load store, data available
                   ~refetch        & wait_next_instr & ram_done_pulsed,    // instruction avalable
                   ~refetch        & commit_decode
                  };
                  
  } 
  
  // boot
  ram.addr     = boot_at;
  ram.rw       = 0;
  ram.in_valid = 1;
  
  while (!halt) {
  // while (cycle < 400) {
  // while (instret < 128) {

    if (ram_done_pulsed) {
      __display("[ram_done_pulsed] ram.data_out %h",ram.data_out);        
    }

    switch (case_select) {
    
      case 8: {
      ram_done_pulsed = 0;
      __display("----------- CASE 8 ------------- (cycle %d)",cycle);     
$$if SIMULATION then
        __display("[refetch] (cycle %d) @%h",cycle,ram.addr);        
$$end
        refetch         = 0;

        // record next instruction
        next_instr      = ram.data_out;
        next_instr_pc   = ram.addr;
__display("[NEXT instr] %h @%h",next_instr,next_instr_pc);
        // prepare load registers for next instruction
        xregsA.addr0    = Rtype(next_instr).rs1;
        xregsB.addr0    = Rtype(next_instr).rs2;
__display("[setup regs read] regA[%d] regB[%d]",xregsA.addr0,xregsB.addr0);        

        // refetch
        ram.addr        = refetch_addr;
        ram.rw          = refetch_rw;
        ram.in_valid    = 1;
        instr           = do_load_store ? instr : 0; // reset decoder
        wait_next_instr = ~do_load_store ;

      }
    
      case 4: {
      __display("----------- CASE 4 ------------- (cycle %d)",cycle);
        ram_done_pulsed = 0;
$$if SIMULATION then
        __display("[load store] (cycle %d) store %b",cycle,saved_store);
$$end        
        do_load_store   = 0;
        // data with memory access
        if (~saved_store) { 
          // finalize load
          uint32 tmp = uninitialized;
          switch ( saved_loadStoreOp[0,2] ) {
            case 2b00: { // LB / LBU
              tmp = { {24{saved_loadStoreOp[2,1]&ram.data_out[ 7,1]}},ram.data_out[ 0,8]};
            }
            case 2b01: { // LH / LHU
              tmp = { {16{saved_loadStoreOp[2,1]&ram.data_out[15,1]}},ram.data_out[ 0,16]};
            }
            case 2b10: { // LW
              tmp = ram.data_out;  
            }
            default: { tmp = 0; }
          }            
          // write result to register
          xregsA.wenable1 = saved_rd_enable;
          xregsB.wenable1 = saved_rd_enable;
          xregsA.wdata1   = tmp;
          xregsB.wdata1   = tmp;
$$if SIMULATION then
if (xregsA.wenable1) {
__display("[regs WRITE] regA[%d]=%h regB[%d]=%h",xregsA.addr1,xregsA.wdata1,xregsB.addr1,xregsB.wdata1);
}
$$end
        }
        
        if ((Rtype(next_instr).rs1 == xregsA.addr1
          || Rtype(next_instr).rs2 == xregsB.addr1) & saved_rd_enable) {
          ram.addr        = pc;
          wait_next_instr = 1;
          instr           = 0; // reset decoder
        } else {
          // be optimistic: request next-next instruction
          ram.addr        = next_instr_pc + 4;
__display("[RAM ADDR] @%h",ram.addr);
          commit_decode     = 1;
        }
        ram.in_valid    = 1;
        ram.rw          = 0;
        //ram.addr        = pc
        //wait_next_instr = 1;
        //instr           = 0; // reset decoder        
      } // case 4

      case 2: {
      ram_done_pulsed = 0;
      __display("----------- CASE 2 ------------- (cycle %d)",cycle);
      __display("========> (cycle %d) ram.data_out:%h",cycle,ram.data_out);
        // Note: ALU for previous (if any) is running ...
        wait_next_instr = 0;
        // record next instruction
        next_instr      = ram.data_out;
        next_instr_pc   = ram.addr;
__display("[NEXT instr] %h @%h",next_instr,next_instr_pc);
        // prepare load registers for next instruction
        xregsA.addr0    = Rtype(next_instr).rs1;
        xregsB.addr0    = Rtype(next_instr).rs2;
__display("[setup regs read] regA[%d] regB[%d]",xregsA.addr0,xregsB.addr0);        
        commit_decode   = 1;
        // be optimistic: request next-next instruction
        ram.addr        = (ram.addr[0,26] + 4);
__display("[RAM ADDR] @%h",ram.addr);
        ram.in_valid    = 1;
        ram.rw          = 0;
      }
      
      case 1: {
        int32 from_csr = uninitialized;
      __display("----------- CASE 1 ------------- (cycle %d)",cycle);
        if (instr == 0) {
          __display("========> [next instruction] (cycle %d) load_store %b branch_or_jump %b",cycle,load_store,branch_or_jump);
        } else {
          __display("========> [ALU done (%h)   ] (cycle %d) pc %h alu_out %h load_store:%b store:%b branch_or_jump:%b rd_enable:%b write_rd:%d aluA:%d aluB:%d",instr,cycle,pc,alu_out,load_store,store,branch_or_jump,rd_enable,write_rd,aluA,aluB);
        }
        commit_decode = 0;
        // Note: nothing received from memory
        
        if (instr != 0) {
          instret = instret + 1;
$$if SIMULATION then          
          __display("========> [retired instruction] *** %d since ***",cycle-cycle_last_retired);
          cycle_last_retired = cycle;
$$end          
        }
        
        // commit previous instruction
        // load store next?
        do_load_store     = load_store; // Note instr == 0 => load_store == 0        
        saved_store       = store;
        saved_loadStoreOp = loadStoreOp;
        saved_rd_enable   = rd_enable;
        // what to request from RAM next?
        refetch           = (branch_or_jump | load_store); // ask to fetch from the new address (cannot do it now, memory is busy with prefetch)
        refetch_addr      = alu_out;
        refetch_rw        = load_store & store;            // Note: (instr == 0) => load_store = 0
$$if SIMULATION then
if (refetch) {
  __display("[refetch from] %h",refetch_addr);
}
$$end
        // wait for next instr?
        wait_next_instr = ~refetch & ~do_load_store;
        // prepare a potential store     // Note: it is ok to manipulate ram.data_in as only reads can concourrently occur
        switch (loadStoreOp) {
          case 3b000: { // SB
              switch (alu_out[0,2]) {
                case 2b00: { ram.data_in[ 0,8] = aluB[ 0,8]; ram.wmask = 4b0001; }
                case 2b01: { ram.data_in[ 8,8] = aluB[ 0,8]; ram.wmask = 4b0010; }
                case 2b10: { ram.data_in[16,8] = aluB[ 0,8]; ram.wmask = 4b0100; }
                case 2b11: { ram.data_in[24,8] = aluB[ 0,8]; ram.wmask = 4b1000; }
              }
          }
          case 3b001: { // SH
              switch (alu_out[1,1]) {
                case 1b0: { ram.data_in[ 0,16] = aluB[ 0,16]; ram.wmask = 4b0011; }
                case 1b1: { ram.data_in[16,16] = aluB[ 0,16]; ram.wmask = 4b1100; }
              }
          }
          case 3b010: { // SW
            ram.data_in = aluB; ram.wmask = 4b1111;
          }
          default: { ram.data_in = 0; }
        }        
        // store result in registers
        // -> what do we write in register? (pc or alu or csr? -- loads are handled above)
        // csr
        switch (csr[0,2]) {
          case 2b00: { from_csr = cycle;   }
          case 2b01: { from_csr = cpu_id;  }
          case 2b10: { from_csr = instret; }
          default: { }
        }
        // write result to register
        xregsA.wdata1   = branch_or_jump ? next_instr_pc : (csr[2,1] ? from_csr :  alu_out);
        xregsB.wdata1   = branch_or_jump ? next_instr_pc : (csr[2,1] ? from_csr :  alu_out);
        xregsA.addr1    = write_rd;
        xregsB.addr1    = write_rd;
        xregsA.wenable1 = (~refetch | jump) & rd_enable; // Note: instr == 0 => rd_enable == 0 
        xregsB.wenable1 = (~refetch | jump) & rd_enable; // postpone write if refetch (load)
if (xregsA.wenable1) {        
__display("[regs WRITE] regA[%d]=%h regB[%d]=%h",xregsA.addr1,xregsA.wdata1,xregsB.addr1,xregsB.wdata1);
}
        // setup decoder and ALU for instruction i+1
        instr = next_instr;
        pc    = next_instr_pc;
__display("[instr setup] %h @%h",instr,pc);
        regA  = ((xregsA.addr0 == xregsA.addr1) & xregsA.wenable1) ? xregsA.wdata1 : xregsA.rdata0;
        regB  = ((xregsB.addr0 == xregsB.addr1) & xregsB.wenable1) ? xregsB.wdata1 : xregsB.rdata0;   
__display("[regs READ] regA[%d]=%h (%h) regB[%d]=%h (%h)",xregsA.addr0,regA,xregsA.rdata0,xregsB.addr0,regB,xregsB.rdata0);        
      }
    } // switch
        
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
  input  uint32  instr,
  input  uint26  pc,
  input  int32   regA,
  input  int32   regB,
  output uint26  next_pc,
  output uint5   write_rd,
  output uint1   jump,
  output uint1   branch,
  output uint1   load_store,
  output uint1   store,
  output uint3   loadStoreOp,
  output uint3   select,
  output uint1   select2,
  output int32   imm,
  output uint1   pcOrReg,
  output uint1   regOrImm,
  output uint3   csr,
  output uint1   rd_enable,
  output int32   aluA,
  output int32   aluB,
) <autorun> {

  int32 imm_u  := {Utype(instr).imm31_12,12b0};
  int32 imm_j  := {
           {12{Jtype(instr).imm20}},
           Jtype(instr).imm_19_12,
           Jtype(instr).imm11,
           Jtype(instr).imm10_1,
           1b0};
  int32 imm_i  := {{20{instr[31,1]}},Itype(instr).imm};
  int32 imm_b  :=  {
            {20{Btype(instr).imm12}},
            Btype(instr).imm11,
            Btype(instr).imm10_5,
            Btype(instr).imm4_1,
            1b0
            };
  int32 imm_s  := {{20{instr[31,1]}},Stype(instr).imm11_5,Stype(instr).imm4_0};
  
  uint7 opcode := instr[ 0, 7];
  
/*
  7b0010111  AUIPC
  7b0110111  LUI
  7b1101111  JAL
  7b1100111  JALR
  7b1100011  branch
  7b0000011  load
  7b0100011  store
  7b0010011  integer, immediate  
  7b0110011  integer, registers
  7b1110011  timers
*/
  
  uint1 no_rd  := (opcode == 7b1100011 || opcode == 7b0100011);

  next_pc      := pc + 4;

  jump         := (opcode == 7b1101111 || opcode == 7b1100111);
  branch       := (opcode == 7b1100011);
  load_store   := (opcode == 7b0000011 || opcode == 7b0100011);
  store        := (opcode == 7b0100011);
  select       := (opcode == 7b0010011 || opcode == 7b0110011) ? Itype(instr).funct3 : 0;
  select2      := (opcode == 7b0010011 
                   && instr[30,1] /*SRLI/SRAI*/ 
                   && (Itype(instr).funct3 != 3b000) /*not ADD*/) 
               || (opcode == 7b0110011 && Rtype(instr).select2);
  
  loadStoreOp  := Itype(instr).funct3;

  write_rd     := Rtype(instr).rd;
  rd_enable    := (write_rd != 0) & ~no_rd;  
  
  pcOrReg      := (opcode == 7b0010111 || opcode == 7b1101111 || opcode == 7b1100011);
                
  regOrImm     := (opcode == 7b0110011);

  csr          := {opcode == 7b1110011,instr[20,2]}; // we grab only the bits for 
               // low bits of rdcycle (0xc00), rdtime (0xc01), instret (0xc02)
  
  aluA         := (opcode == 7b0110111) ? 0 : regA;
  aluB         := regB;

  always {
// __display("DECODE %d %d",regA,regB);
    switch (opcode)
    {    
      case 7b0010111: { // AUIPC
        imm         = imm_u;
      }
      case 7b0110111: { // LUI
        imm         = imm_u;
      }
      case 7b1101111: { // JAL
        imm         = imm_j;
      }
      case 7b1100111: { // JALR
        imm         = imm_i;
      }
      case 7b1100011: { // branch
        imm         = imm_b;
      } 
      case 7b0000011: { // load
        imm         = imm_i;
      }      
      case 7b0100011: { // store
        imm         = imm_s;
      }
      case 7b0010011: { // integer, immediate  
        imm         = imm_i;
      }
      default: {
      }
    }
  }
  /*
    always {  
      if (opcode == 7b0010111 || opcode == 7b0110111) {
        imm = imm_u;
      } else { if (opcode == 7b1101111) {
        imm = imm_j;    
      } else { if (opcode == 7b1100111 || opcode == 7b0000011 || opcode == 7b0010011) {
        imm = imm_i;
      } else { if (opcode == 7b1100011) {
        imm = imm_b;
      } else { if (opcode == 7b0100011) {
        imm = imm_s;
      } } } } }
    }
  */  
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
  input!  uint1  pcOrReg,
  input!  uint1  regOrImm,
  output  int32  r,
) {
  
  // 3 cases
  // reg +/- reg (intops)
  // reg +/- imm (intops)
  // pc  + imm   (else)
  
  int32 a := pcOrReg  ? __signed({6b0,pc[0,26]}) : xa;
  int32 b := regOrImm ? (xb) : imm;

  always { // this part of the algorithm is executed every clock  
    switch (select) {
      case 3b000: { // ADD / SUB
        r = a + (select2 ? -b : b);
        // r = select2 ? (a - b) : (a + b);
      }
      case 3b010: { // SLTI
        if (__signed(xa) < __signed(b)) { r = 32b1; } else { r = 32b0; }
      }
      case 3b011: { // SLTU
        if (__unsigned(xa) < __unsigned(b)) { r = 32b1; } else { r = 32b0; }
      }
      case 3b100: { r = xa ^ b;} // XOR
      case 3b110: { r = xa | b;} // OR
      case 3b111: { r = xa & b;} // AND
      case 3b001: { r = (xa <<< b[0,5]); } // SLLI
      case 3b101: { r = select2 ? (xa >>> b[0,5]) : (xa >> b[0,5]); } // SRLI / SRAI
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
  output  uint1 j,
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
