// SL 2020-12-02 @sylefeb
//
// RISC-V with SDRAM IO
// Based on the ice-v
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
  uint1   rw         = 0,
  uint4   wmask      = 0, // write mask
  uint32  data_in    = 0,
  uint32  data_out   = 0,
  uint1   busy       = 1,
  uint1   in_valid   = 0,
  uint1   out_valid  = 0
}

// interface for user
interface rv32i_ram_user {
  output  addr,
  output  rw,
  output  wmask,
  output  data_in,
  output  in_valid,
  input   data_out,
  input   busy,
  input   out_valid,
}

// interface for provider
interface rv32i_ram_provider {
  input   addr,
  input   rw,
  input   wmask,
  input   data_in,
  output  data_out,
  output  busy,
  input   in_valid,
  output  out_valid
}


// --------------------------------------------------
// The Risc-V RV32I CPU

algorithm rv32i_cpu(
  input uint1    enable,
  rv32i_ram_user ram
) <autorun> {
  
  //                 |--------- indicates we don't want the bram inputs to be latched
  //                 v          writes have to be setup during the same clock cycle
  bram int32 xregsA<input!>[32] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  bram int32 xregsB<input!>[32] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  
  uint1  load_next_instr = uninitialized;
  
  uint1  cmp         = uninitialized;
  
  uint5  write_rd    = uninitialized;
  uint1  jump        = uninitialized;  
  uint1  branch      = uninitialized;
  
  uint1  load_store  = uninitialized;
  uint1  store       = uninitialized;
  
  uint3  select      = uninitialized;  
  uint1  select2     = uninitialized;

  uint32 instr       = uninitialized;
  uint12 pc          = uninitialized;
  
  uint12 next_pc   ::= pc+1; // next_pc tracks the expression 'pc + 1' using the
                             // value of pc from the last clock edge (due to ::)

$$if SIMULATION then  
$$if SHOW_REGS then
$$for i=0,31 do
  int32 xv$i$ = uninitialized;
$$end
$$end
$$end

  int32  alu_out     = uninitialized;
  intops alu(
    pc        <: pc,
    xa        <: xregsA.rdata,
    xb        <: xregsB.rdata,
    imm       <: imm,
    forceZero <: forceZero,
    regOrPc   <: regOrPc,
    regOrImm  <: regOrImm,
    r         :> alu_out,
    select    <: select,
    select2   <: select2,
  );

  int32 imm         = uninitialized;
  uint1 forceZero   = uninitialized;
  uint1 regOrPc     = uninitialized;
  uint1 regOrImm    = uninitialized;
  uint3 loadStoreOp = uninitialized;
  decode dec(
    instr       <:: instr,    // the <:: indicates we bind the variable as it was at the last
    write_rd    :> write_rd,  // clock edge (as opposed to its value being modified in this cycle)
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
    regOrImm    :> regOrImm
  );
 
  uint3 funct3   ::= Btype(instr).funct3;
  
  intcmp cmps(
    a      <: xregsA.rdata,
    b      <: xregsB.rdata,
    select <: funct3,
    enable <: branch,
    j      :> cmp
  ); 

$$if SIMULATION then
  uint16 iter = 0;
$$end

  uint1  out_valid_pulsed = uninitialized;

  // maintain ram in_valid low (pulses high when needed)
  ram.in_valid   := 0; 
  // maintain read registers (no latched, see bram parameter)
  xregsA.wenable := 0;
  xregsB.wenable := 0;
  xregsA.addr    := Rtype(instr).rs1;
  xregsB.addr    := Rtype(instr).rs2;  

  always {
    out_valid_pulsed = out_valid_pulsed | ram.out_valid;
  } 
  
  // boot at 0x00
  load_next_instr =  1;
  ram.addr        =  0;
  ram.rw          =  0;
  pc              = -1;
  
  while (1) {
  
    // __display("CPU ram @%h load_next_instr %b load_store %b store %b",ram.addr,load_next_instr,load_store,store);

    // wait for memory
    while ( !enable || 
      ( ( (load_store && store) || load_next_instr )
        ?  ram.busy
        : !out_valid_pulsed )
    ) { /*__display("wait (@%h) %b busy:%b out:%b load_next_instr:%b",ram.addr,enable,ram.busy,ram.out_valid,load_next_instr);*/ }
    
    out_valid_pulsed = 0;
    
    // ram is not busy, or data is available
    
    if (load_next_instr == 1) {
      // __display("[load_next_instr]");
    
      // load next instruction
      load_next_instr = 0;
      ram.addr        = ((~load_store) && (jump | cmp)) ? alu_out[2,12]  : next_pc;
      ram.rw          = 0;
      ram.in_valid    = 1;
      // null instruction (sets all decode low, so load_store == 0)
      instr           = 0;
    
    } else { if (load_store) {
      // __display("[load_store]");
    
      if (~store) { // load
      
        // data is available, ram may be busy
        uint32 tmp = uninitialized;
        switch ( loadStoreOp[0,2] ) {
          case 2b00: { // LB / LBU
              switch (alu_out[0,2]) {
                case 2b00: { tmp = { {24{loadStoreOp[2,1]&ram.data_out[ 7,1]}},ram.data_out[ 0,8]}; }
                case 2b01: { tmp = { {24{loadStoreOp[2,1]&ram.data_out[15,1]}},ram.data_out[ 8,8]}; }
                case 2b10: { tmp = { {24{loadStoreOp[2,1]&ram.data_out[23,1]}},ram.data_out[16,8]}; }
                case 2b11: { tmp = { {24{loadStoreOp[2,1]&ram.data_out[31,1]}},ram.data_out[24,8]}; }
                default:   { tmp = 0; }
              }
          }
          case 2b01: { // LH / LHU
              switch (alu_out[1,1]) {
                case 1b0: { tmp = { {16{loadStoreOp[2,1]&ram.data_out[15,1]}},ram.data_out[ 0,16]}; }
                case 1b1: { tmp = { {16{loadStoreOp[2,1]&ram.data_out[31,1]}},ram.data_out[16,16]}; }
                default:  { tmp = 0; }
              }
          }
          case 2b10: { // LW
            tmp = ram.data_out;  
          }
          default: { tmp = 0; }
        }            
        // __display("LOAD addr: %h (%b) op: %b read: %h / %h", ram.addr, alu_out, loadStoreOp, ram.data_out, tmp);
        
        // commit result
        xregsA.wenable = 1;
        xregsB.wenable = 1;
        xregsA.wdata   = tmp;
        xregsB.wdata   = tmp;
        xregsA.addr    = write_rd;
        xregsB.addr    = write_rd;      

      } else { // store

        // ram is not busy, execute store
        ram.in_valid    = 1;
        
      }

      // next instruction
      load_next_instr = 1;
      
    } else {
      // __display("[exec] instr = %h",ram.data_out);

      // instruction available
    
      // ready
      instr       = ram.data_out;
      pc          = ram.addr;
      // update register immediately
      xregsA.addr = Rtype(instr).rs1;
      xregsB.addr = Rtype(instr).rs2;  

    ++: // decode and ALU
    ++: // decode and ALU
    
      // ram may again be busy
    
      if (load_store) {
      
        // prepare load/store
        ram.rw       = store;
        ram.addr     = alu_out>>2;      
        // store? set data
        if (store) { 
          switch (loadStoreOp) {
            case 3b000: { // SB
                switch (alu_out[0,2]) {
                  case 2b00: { ram.data_in[ 0,8] = xregsB.rdata[ 0,8]; ram.wmask = 4b0001; }
                  case 2b01: { ram.data_in[ 8,8] = xregsB.rdata[ 0,8]; ram.wmask = 4b0010; }
                  case 2b10: { ram.data_in[16,8] = xregsB.rdata[ 0,8]; ram.wmask = 4b0100; }
                  case 2b11: { ram.data_in[24,8] = xregsB.rdata[ 0,8]; ram.wmask = 4b1000; }
                }
            }
            case 3b001: { // SH
                switch (alu_out[1,1]) {
                  case 1b0: { ram.data_in[ 0,16] = xregsB.rdata[ 0,16]; ram.wmask = 4b0011; }
                  case 1b1: { ram.data_in[16,16] = xregsB.rdata[ 0,16]; ram.wmask = 4b1100; }
                }
            }
            case 3b010: { // SW
              ram.data_in = xregsB.rdata; ram.wmask = 4b1111;
            }
            default: { ram.data_in = 0; }
          }          
        }
        // __display("STORE addr: %h (%b) op: %b to_store: %h", ram.addr, alu_out, loadStoreOp, ram.data_in);
        
      } else {

        // what do we write in register (pc or alu, load is handled above)
        xregsA.wdata = (jump | cmp) ? (next_pc) << 2 : alu_out;
        xregsB.wdata = (jump | cmp) ? (next_pc) << 2 : alu_out;
        
        // store result   
        if (write_rd) {
          // commit result
          xregsA.wenable = 1;
          xregsB.wenable = 1;
          xregsA.addr    = write_rd;
          xregsB.addr    = write_rd;
        }        
        
        // next instruction
        load_next_instr = 1;

      }
    } }

$$if SIMULATION then  
$$if SHOW_REGS then  
++:
  xregsA.wenable = 0;
  xregsB.wenable = 0;
  __display("------------------ registers A ------------------");
$$for i=0,31 do
      xregsA.addr = $i$;
++:
      xv$i$ = xregsA.rdata;
$$end
      __display("%h %h %h %h\\n%h %h %h %h\\n%h %h %h %h\\n%h %h %h %h",xv0,xv1,xv2,xv3,xv4,xv5,xv6,xv7,xv8,xv9,xv10,xv11,xv12,xv13,xv14,xv15);
      __display("%h %h %h %h\\n%h %h %h %h\\n%h %h %h %h\\n%h %h %h %h",xv16,xv17,xv18,xv19,xv20,xv21,xv22,xv23,xv24,xv25,xv26,xv27,xv28,xv29,xv30,xv31);
$$end
$$end

  }

}

// --------------------------------------------------
// decode next instruction

algorithm decode(
  input   uint32  instr,
  output! uint5   write_rd,
  output! uint1   jump,
  output! uint1   branch,
  output! uint1   load_store,
  output! uint1   store,
  output! uint3   loadStoreOp,
  output! uint3   select,
  output! uint1   select2,
  output! int32   imm,
  output! uint1   forceZero,
  output! uint1   regOrPc,
  output! uint1   regOrImm
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
      }
 
      case 7b0000011: { // load
        // __display("LOAD");
        write_rd    = Rtype(instr).rd;
        jump        = 0;
        branch      = 1;
        load_store  = 1;
        store       = 0;
        loadStoreOp = Itype(instr).funct3;
        select      = 0;
        select2     = 0;
        imm         = {{20{instr[31,1]}},Itype(instr).imm};
        forceZero   = 1;
        regOrPc     = 0; // reg
        regOrImm    = 1; // imm
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
      }
    }
  }
}

// --------------------------------------------------
// Performs integer computations

algorithm intops(         // input! tells the compiler that the input does not                            
  input!  uint12 pc,      // need to be latched, so we can save registers
  input!  int32  xa,      // caller has to ensure consistency
  input!  int32  xb,
  input!  int32  imm,
  input!  uint3  select,
  input!  uint1  select2,
  input!  uint1  forceZero,
  input!  uint1  regOrPc,
  input!  uint1  regOrImm,
  output  int32  r,
) {
  
  int32 a := regOrPc  ? __signed({20b0,pc[0,10],2b0}) : (forceZero ? xa : __signed(32b0));
  int32 b := regOrImm ? imm : (xb);
  //      ^^
  // using := during a declaration means that the variable now constantly tracks
  // the declared expression (but it is no longer assignable)
  // In other words, this is a wire!
  
  always { // this part of the algorithm is executed every clock
  
    switch (select) {
      case 3b000: { // ADD / SUB
        int32 tmp = uninitialized;
        if (select2) { tmp = -b; } else { tmp = b; }
        r = a + tmp;
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
      
$$if SIMULATION then
//__display("enable %b a = %d b = %d r = %d select=%d select2=%d working=%d shamt=%d",enable,a,b,r,select,select2,working,shamt);
$$end
  }
  
}

// --------------------------------------------------
// Performs integer comparisons

algorithm intcmp(
  input!  int32 a,
  input!  int32 b,
  input!  uint3 select,
  input!  uint1 enable,
  output! uint1 j,
) {
  always {  
    switch (select) {
      case 3b000: { j = enable & (a == b); } // BEQ
      case 3b001: { j = enable & (a != b); } // BNE
      case 3b100: { j = enable & (__signed(a)   <  __signed(b));   } // BLT
      case 3b110: { j = enable & (__unsigned(a) <  __unsigned(b)); } // BLTU
      case 3b101: { j = enable & (__signed(a)   >= __signed(b));   } // BGE
      case 3b111: { j = enable & (__unsigned(a) >= __unsigned(b)); } // BGEU
      default:    { j = 0; }
    }
$$if SIMULATION then
//__display("a = %d b = %d j = %d select=%d",a,b,j,select);
$$end
  }
}

// --------------------------------------------------
