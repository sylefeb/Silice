import('../../common/ice40_warmboot.v')
import('../bram_fill/ice40_bram.v')

algorithm main(output uint5 leds,input uint3 btns)
{               
  uint23 cnt(0);       
  uint3  rbtns(0);
  uint1  pressed(0);

  uint1  boot(0);
  uint2  slot(0);
  ice40_warmboot wb(boot <: boot,slot <: slot);

  uint8  addr(0);
  uint16 data_in(0);
  uint15 wmask(16b0);
  uint1  wenable(0);
  uint16 data_out0(0);

  ice40_bram mem(
    clock <: clock,
    wdata <: data_in,
    wmask <: wmask,
    wenable <: wenable,
    raddr <: addr,
    waddr <: addr,
    rdata :> data_out0
  );

  slot    := 2b00; // goes back to bootloader (bitstream 0)
                   // the bistream vector in slot 1 is hotswapped by bootloader

  rbtns  ::= btns;  // register input buttons
  boot    := boot | (pressed & ~rbtns[0,1]); // set high on release
  pressed := rbtns[0,1]; // pressed tracks button 1

  leds    := data_out0;

  always {
    addr    = cnt == 0 ? (addr + 1) : addr;
    cnt     = cnt + 1;
  }

}
