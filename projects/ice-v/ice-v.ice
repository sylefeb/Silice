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


// lines:  657
// decode: 55 + 184 = 239
// SOC:    118



// Clocks
$$if ICESTICK then
import('../common/icestick_clk_60.v')
$$end
$$if FOMU then
import('../common/fomu_clk_20.v')
$$end

// --------------------------------------------------

// pre-compilation script, embeds compile code within BRAM
$$dofile('pre_include_asm.lua')

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

algorithm main( // I guess this is the SOC :-D
  output! uint5 leds,
$$if OLED then
  output! uint1 oled_clk,
  output! uint1 oled_mosi,
  output! uint1 oled_dc,
  output! uint1 oled_resn,
  output! uint1 oled_csn,
$$end
$$if ICESTICK then
  ) <@cpu_clock>
{
  // clock  
  icestick_clk_60 clk_gen (
    clock_in  <: clock,
    clock_out :> cpu_clock
  ); 
$$elseif FOMU then
  ) <@cpu_clock>
{
  // clock  
  uint1 cpu_clock  = uninitialized;
  fomu_clk_20 clk_gen (
    clock_in  <: clock,
    clock_out :> cpu_clock
  );  
  
$$else
) {
$$end

$$if OLED then
  uint1 displ_en = uninitialized;
  uint1 displ_dta_or_cmd := mem.wdata[10,1];
  uint8 displ_byte       := mem.wdata[0,8];
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
  bram uint32 mem<input!>[] = $meminit$;
    
  // cpu
  rv32i_cpu cpu( mem <:> mem );

  // io mapping
  always {
$$if OLED then
    displ_en = 0;
$$end
    if (mem.wenable & cpu.wide_addr[10,1]) {
      leds = mem.wdata[0,5] & {5{cpu.wide_addr[0,1]}};
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
// Help send bytes to the OLED screen
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
// The Risc-V RV32I CPU itself

algorithm rv32i_cpu( bram_port mem, output! uint11 wide_addr(0) ) <onehot> {
  //                                           boot address  ^
  //                 |--------- indicates we don't want the bram inputs to be latched
  //                 v          writes have to be setup during the same clock cycle
  bram int32 xregsA<input!>[32] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  bram int32 xregsB<input!>[32] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  
  //uint5  write_rd    = uninitialized;
  //uint1  jump        = uninitialized;  
  //uint1  branch      = uninitialized;
  
  uint32 instr       = uninitialized;
  uint12 pc          = uninitialized;
  
  uint12 next_pc   <:: pc+1; // next_pc tracks the expression 'pc + 1' using the
                             // value of pc from the last clock edge (due to ::)

  uint3 funct3     <: Btype(instr).funct3;
  
  decode dec( instr <:: instr );

  intops alu(
    pc          <: pc,
    xa          <: xregsA.rdata,
    xb          <: xregsB.rdata,
    imm         <: dec.imm,
    forceZero   <: dec.forceZero,
    pcOrReg     <: dec.pcOrReg,
    regOrImm    <: dec.regOrImm,
    aluOp       <: dec.aluOp,
    sub         <: dec.sub,
    signedShift <: dec.signedShift,
  );

  intcmp cmps(
    a      <: xregsA.rdata,
    b      <: xregsB.rdata,
    funct3 <: funct3,
    enable <: dec.branch,
  ); 

  // maintain alu enable low (pulses high when needed)
  alu.enable     := 0;
  // maintain write enable low (pulses high when needed)
  mem.wenable    := 0; 
  // maintain read registers (no latched, see bram parameter)
  xregsA.wenable := 0;
  xregsB.wenable := 0;
  xregsA.addr    := Rtype(instr).rs1;
  xregsB.addr    := Rtype(instr).rs2;  

  always_after { mem.addr = wide_addr[0,10]; /* track memory address */}

  while (1) {

    // data is now available
    instr = mem.rdata;
    pc    = wide_addr;
    // update register immediately
    xregsA.addr = Rtype(instr).rs1;
    xregsB.addr = Rtype(instr).rs2;  

++: // decode

    alu.enable = 1;

    while (1) {

        // load/store?        
        // What happens here: we always load, and mask and store on SB,SH,SW.
        // the reason being that the BRAM design currently does not support
        // write masks (likely to evolve, but have to worry about compatibility 
        // across architectures).
        if (dec.load_store) {        
          // load data (NOTE: could skip if followed by SW)
          wide_addr   = alu.r>>2;
++: // wait data
          if (~dec.store) {
            uint32 tmp = uninitialized;
            switch ( dec.loadStoreOp[0,2] ) {
              case 2b00: { // LB / LBU
                  switch (alu.r[0,2]) {
                    case 2b00: { tmp = { {24{(~dec.loadStoreOp[2,1])&mem.rdata[ 7,1]}},mem.rdata[ 0,8]}; }
                    case 2b01: { tmp = { {24{(~dec.loadStoreOp[2,1])&mem.rdata[15,1]}},mem.rdata[ 8,8]}; }
                    case 2b10: { tmp = { {24{(~dec.loadStoreOp[2,1])&mem.rdata[23,1]}},mem.rdata[16,8]}; }
                    case 2b11: { tmp = { {24{(~dec.loadStoreOp[2,1])&mem.rdata[31,1]}},mem.rdata[24,8]}; }
                    default:   { tmp = 0; }
                  }
              }
              case 2b01: { // LH / LHU
                  switch (alu.r[1,1]) {
                    case 1b0: { tmp = { {16{(~dec.loadStoreOp[2,1])&mem.rdata[15,1]}},mem.rdata[ 0,16]}; }
                    case 1b1: { tmp = { {16{(~dec.loadStoreOp[2,1])&mem.rdata[31,1]}},mem.rdata[16,16]}; }
                    default:  { tmp = 0; }
                  }
              }
              case 2b10: { // LW
                tmp = mem.rdata;  
              }
              default: { tmp = 0; }
            }            
            // commit result
            xregsA.wenable = 1;
            xregsB.wenable = 1;
            xregsA.wdata   = tmp;
            xregsB.wdata   = tmp;
            xregsA.addr    = dec.write_rd;
            xregsB.addr    = dec.write_rd;

          } else {
          
            switch (dec.loadStoreOp) {
              case 3b000: { // SB
                  switch (alu.r[0,2]) {
                    case 2b00: { mem.wdata = { mem.rdata[ 8,24] , xregsB.rdata[ 0,8] };                }
                    case 2b01: { mem.wdata = { mem.rdata[16,16] , xregsB.rdata[ 0,8] , mem.rdata[0, 8] }; }
                    case 2b10: { mem.wdata = { mem.rdata[24, 8] , xregsB.rdata[ 0,8] , mem.rdata[0,16] }; }
                    case 2b11: { mem.wdata = {     xregsB.rdata[ 0,8] , mem.rdata[0,24] };             }
                  }
              }
              case 3b001: { // SH
                  switch (alu.r[1,1]) {
                    case 1b0: { mem.wdata = {   mem.rdata[16,16] , xregsB.rdata[ 0,16] }; }
                    case 1b1: { mem.wdata = { xregsB.rdata[0,16] , mem.rdata[0,16] }; }
                  }
              }
              case 3b010: { // SW
                mem.wdata   = xregsB.rdata;
              }            
              default: {  }
            }
            wide_addr   = alu.r>>2;
            mem.wenable = 1;

++: // wait write

          }
          
          wide_addr = next_pc;
          
          break;
          
        } else {
        
          if (alu.working == 0) { // ALU done?

            // next instruction
            wide_addr    = (dec.jump | cmps.j) ? alu.r[2,12]  : next_pc;
            // what do we write in register (pc or alu, load is handled above)
            xregsA.wdata = (dec.jump | cmps.j) ? (next_pc) << 2 : alu.r;
            xregsB.wdata = (dec.jump | cmps.j) ? (next_pc) << 2 : alu.r;
            
            // store result   
            if (dec.write_rd != 5b0) {
              // commit result
              xregsA.wenable = 1;
              xregsB.wenable = 1;
              xregsA.addr    = dec.write_rd;
              xregsB.addr    = dec.write_rd;
            }        

            break;
          }      
        }
      }

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
  output! uint3   aluOp,
  output! uint1   sub,  
  output! uint1   signedShift,
  output! int32   imm,
  output! uint1   forceZero,
  output! uint1   pcOrReg,
  output! uint1   regOrImm
) {

  int32 imm_u  <: {Utype(instr).imm31_12,12b0};
  int32 imm_j  <: {
           {12{Jtype(instr).imm20}},
           Jtype(instr).imm_19_12,
           Jtype(instr).imm11,
           Jtype(instr).imm10_1,
           1b0};
  int32 imm_i  <: {{20{instr[31,1]}},Itype(instr).imm};
  int32 imm_b  <:  {
            {20{Btype(instr).imm12}},
            Btype(instr).imm11,
            Btype(instr).imm10_5,
            Btype(instr).imm4_1,
            1b0
            };
  int32 imm_s  <: {{20{instr[31,1]}},Stype(instr).imm11_5,Stype(instr).imm4_0};
  
  uint5 opcode <: instr[ 2, 5];
  
  uint1 AUIPC  <: opcode == 5b00101;
  uint1 LUI    <: opcode == 5b01101;
  uint1 JAL    <: opcode == 5b11011;
  uint1 JALR   <: opcode == 5b11001;
  uint1 Branch <: opcode == 5b11000;
  uint1 Load   <: opcode == 5b00000;
  uint1 Store  <: opcode == 5b01000;
  uint1 IntImm <: opcode == 5b00100;
  uint1 IntReg <: opcode == 5b01100;
  uint1 no_rd  <: (Branch | Store);

  jump         := (JAL | JALR);
  branch       := (Branch);
  store        := (Store);
  load_store   := (Load | Store);
  regOrImm     := (IntReg);
  aluOp        := (IntImm | IntReg) ? {Itype(instr).funct3} : 3b000;
  sub          := (IntReg & Rtype(instr).select2);
  signedShift  := IntImm & instr[30,1]; /*SRLI/SRAI*/
  loadStoreOp  := Itype(instr).funct3;
  write_rd     := no_rd ? 5b0 : Rtype(instr).rd;
  pcOrReg      := (AUIPC | JAL | Branch);
  forceZero    := LUI;

  always {
    switch (opcode)
     {
      case 5b00101: { imm = imm_u; } // AUIPC
      case 5b01101: { imm = imm_u; } // LUI
      case 5b11011: { imm = imm_j; } // JAL
      case 5b11000: { imm = imm_b; } // branch
      case 5b11001: { imm = imm_i; } // JALR
      case 5b00000: { imm = imm_i; } // load
      case 5b00100: { imm = imm_i; } // integer, immediate
      case 5b01000: { imm = imm_s; } // store
      default:      { imm = {32{1bx}}; }
     }
  }

}

// --------------------------------------------------
// Performs integer computations

algorithm intops(
  input   uint12 pc,
  input   int32  xa,
  input   int32  xb,
  input   int32  imm,
  input   uint3  aluOp,
  input   uint1  sub,  
  input   uint1  signedShift,
  input   uint1  forceZero,
  input   uint1  pcOrReg,
  input   uint1  regOrImm,
  input   uint1  enable,
  output  int32  r,
  output  uint1  working,
) {
  uint1 signed = 0;
  uint1 dir    = 0;
  uint5 shamt  = 0;
  
  int32 a <: forceZero ?  __signed(32b0) : (pcOrReg  ? __signed({20b0,pc[0,10],2b0}) : xa);
  int32 b <: regOrImm ? (xb) : imm;
  
  always { // this part of the algorithm is executed every clock
  
    signed  = signedShift;
    dir     = aluOp[2,1];
    shamt   = working ? shamt - 1 : ((aluOp[0,2] == 2b01) ? __unsigned(b[0,5]) : 0);

    if (working) {    
      // process the shift one bit at a time
      r       = dir ? (signed ? {r[31,1],r[1,31]} : {__signed(1b0),r[1,31]}) 
                    : {r[0,31],__signed(1b0)};      
    } else {

      switch (aluOp) {
        case 3b000: { // ADD / SUB
          // int32 tmp = uninitialized;
          // if (select2) { tmp = -b; } else { tmp = b; }
          r = sub ? a - b : a + b;
        }
        case 3b010: { // SLTI
          if (__signed(a) < __signed(b))     { r = 32b1; } else { r = 32b0; }
        }
        case 3b011: { // SLTU
          if (__unsigned(a) < __unsigned(b)) { r = 32b1; } else { r = 32b0; }
        }
        case 3b100: { r = a ^ b;} // XOR
        case 3b110: { r = a | b;} // OR
        case 3b111: { r = a & b;} // AND
        case 3b001: { // SLLI
          r       = a;
        }
        case 3b101: { // SRLI / SRAI
          r       = a;
        }        
      }    
      
    }

    working = (shamt != 0);

  }
  
}

// --------------------------------------------------
// Performs integer comparisons

algorithm intcmp(
  input   int32 a,
  input   int32 b,
  input   uint3 funct3,
  input   uint1 enable,
  output! uint1 j,
) {
  always {  
    switch (funct3) {
      case 3b000: { j = enable & (a == b); } // BEQ
      case 3b001: { j = enable & (a != b); } // BNE
      case 3b100: { j = enable & (__signed(a)   <  __signed(b));   } // BLT
      case 3b110: { j = enable & (__unsigned(a) <  __unsigned(b)); } // BLTU
      case 3b101: { j = enable & (__signed(a)   >= __signed(b));   } // BGE
      case 3b111: { j = enable & (__unsigned(a) >= __unsigned(b)); } // BGEU
      default:    { j = 0; }
    }
  }
}
// --------------------------------------------------
