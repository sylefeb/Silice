// SL 2020-12-22 @sylefeb
//
// ------------------------- 
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

/*

Dedicated memory for the IceBreaker Ice40 with SPRAM

Implements a memory space with:
- 0x00000 to 0x0FFFF mapped to SPRAM
- 0x10000 to 0x17FFF mapped to bram (boot)

Two sprams are used, spram0 for bits 0-15, spram1 for bits 16-31

A bram override is provided: after booting from the bram segments,
it can be used to exchange data between co-processors and CPU.
Co-processors write through the override, while the CPU reads only.

*/ 

$$if not bram_depth then
$$ if SIMULATION then
$$  bram_depth = 13
$$ else
$$  bram_depth = 11
$$ end
$$end

$$ bram_size  = 1<<bram_depth
$$ print('##### code size: ' .. code_size_bytes .. ' BRAM capacity: ' .. 4*bram_size .. '#####')

$$if bram_depth > 14 then error('bram larger than spram') end

$$config['simple_dualport_bram_wmask_byte_wenable1_width'] = 'data'

algorithm bram_segment_spram_32bits(
  rv32i_ram_provider     pram,               // provided ram interface
  input uint26           predicted_addr,     // next predicted address
  input uint1            predicted_correct,  // was the prediction correct?
  // 
  input uint1            bram_override_we,   // bram override: write enable
  input uint$bram_depth$ bram_override_addr, // bram override: write address
  input uint32           bram_override_data, // bram override: data to be written
) <autorun> {

  simple_dualport_bram uint32 mem<"simple_dualport_bram_wmask_byte">[$bram_size$] = { file("data.img"), pad(uninitialized) };
  
  uint14 sp0_addr(0);
  uint16 sp0_data_in(0);
  uint1  sp0_wenable(0);
  uint4  sp0_wmask(0);
  uint16 sp0_data_out(0);
  
  uint14 sp1_addr(0);
  uint16 sp1_data_in(0);
  uint1  sp1_wenable(0);
  uint4  sp1_wmask(0);
  uint16 sp1_data_out(0);
  
$$if VERILATOR then
  simulation_spram spram0(
$$else
  ice40_spram spram0(
    clock    <: clock, 
$$end  
    addr     <: sp0_addr,
    data_in  <: sp0_data_in,
    wenable  <: sp0_wenable,
    wmask    <: sp0_wmask,
    data_out :> sp0_data_out
  );

$$if VERILATOR then
  simulation_spram spram1(
$$else
  ice40_spram spram1(
    clock    <: clock,
$$end  
    addr     <: sp1_addr,
    data_in  <: sp1_data_in,
    wenable  <: sp1_wenable,
    wmask    <: sp1_wmask,
    data_out :> sp1_data_out
  );

  // track when address is in bram region and onto which entry   
  uint1  in_bram            <:  pram.addr [16,1];
  
  uint1  not_mapped         <:: ~pram.addr[31,1]; // Note: memory mapped addresses flagged by bit 31
  uint14 predicted          <:: predicted_addr[2,14];

  uint14 addr               <:: (pram.in_valid & (~predicted_correct | pram.rw))
                               ? pram.addr[2,14] // read addr next (wait_one)
                               : predicted; // predict

  uint1 wait_one(0);

  always {
$$if verbose then
   if (pram.in_valid & not_mapped) {
     if (pram.rw) {
       __display("RAM %h | %h (bram:%b) (in: %h wm: %b)",pram.addr,addr,in_bram,pram.data_in,pram.wmask);
     } else {
       __display("RAM %h predok:%b (bram:%b) spram@%h next@%h data:%h|%h",pram.addr,predicted_correct,in_bram,sp0_addr,addr,sp0_data_out,sp1_data_out);
     }
   }
   //if (pram.in_valid & pram.rw & ~in_bram & not_mapped) {
   //  __display("RAM %h (bram:%b) (in: %h wm: %b)",pram.addr,in_bram,pram.data_in,pram.wmask);
   //}
$$end

    // result
    pram.data_out       = in_bram
                        ? (mem.rdata0                  >> {pram.addr[0,2],3b000})
                        : ({sp1_data_out,sp0_data_out} >> {pram.addr[0,2],3b000});
    pram.done           = (/*in_bram &*/ predicted_correct & pram.in_valid) | (pram.rw & pram.in_valid) | wait_one;

    // access bram
    mem.addr0           = addr;
    mem.addr1           = bram_override_we ? bram_override_addr : pram.addr[2,$bram_depth$];
    mem.wenable1        = (pram.wmask & {4{pram.rw & pram.in_valid & not_mapped & in_bram}}) | {4{bram_override_we}};
    mem.wdata1          = bram_override_we ? bram_override_data : pram.data_in;

    // access sprams
    sp0_addr            = addr;
    sp1_addr            = addr;
    sp0_data_in         = pram.data_in[ 0,16];
    sp1_data_in         = pram.data_in[16,16];
    sp0_wenable         = pram.rw & pram.in_valid & ~in_bram & not_mapped;
    sp1_wenable         = pram.rw & pram.in_valid & ~in_bram & not_mapped;
    sp0_wmask           = {pram.wmask[1,1],pram.wmask[1,1],pram.wmask[0,1],pram.wmask[0,1]};
    sp1_wmask           = {pram.wmask[3,1],pram.wmask[3,1],pram.wmask[2,1],pram.wmask[2,1]};

$$if verbose then
   if (wait_one) {
     __display("RAM waited");
   }
   if (pram.done & not_mapped) {
     if (~pram.rw) {
       __display("RAM %h read: %h",pram.addr,pram.data_out);
     }
     if (~in_bram) {
      __display("spram rw:%b addr: %h data: %h,%h wm:%b|%b we:%b",sp0_wenable,sp0_addr,sp1_data_in,sp0_data_in,sp1_wmask,sp0_wmask,sp0_wenable);
     }
   }
$$end

    // wait next cycle?
    wait_one            = pram.in_valid & ((~predicted_correct & ~pram.rw) | ~not_mapped /*| (~in_bram & ~pram.rw)*/);

  }
 
}
