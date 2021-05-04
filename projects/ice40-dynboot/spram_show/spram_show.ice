import('../../common/ice40_warmboot.v')
import('../../common/ice40_spram.v')

algorithm main(output uint5 leds,input uint3 btns)
{               
  uint24 cnt(0);       
  uint3  rbtns(0);
  uint1  pressed(0);

  uint1  boot(0);
  uint2  slot(0);
  ice40_warmboot wb(boot <: boot,slot <: slot);

  uint14 addr(0);
  uint16 data_in(0);
  uint4  wmask(0);
  uint1  wenable(0);
  uint16 data_out0(0);
  uint16 data_out1(0);
  uint16 data_out2(0);
  uint16 data_out3(0);

  ice40_spram spram0(
    clock    <: clock,
    addr     <: addr,
    data_in  <: data_in,
    wmask    <: wmask,
    wenable  <: wenable,
    data_out :> data_out0
    );
  ice40_spram spram1(
    clock    <: clock,
    addr     <: addr,
    data_in  <: data_in,
    wmask    <: wmask,
    wenable  <: wenable,
    data_out :> data_out1
    );
  ice40_spram spram2(
    clock    <: clock,
    addr     <: addr,
    data_in  <: data_in,
    wmask    <: wmask,
    wenable  <: wenable,
    data_out :> data_out2
    );
  ice40_spram spram3(
    clock    <: clock,
    addr     <: addr,
    data_in  <: data_in,
    wmask    <: wmask,
    wenable  <: wenable,
    data_out :> data_out3
    );

  slot    := 2b00; // goes back to bootloader (bitstream 0)
                   // the bistream vector in slot 1 is hotswapped by bootloader

  rbtns  ::= btns;  // register input buttons
  boot    := boot | (pressed & ~rbtns[0,1]); // set high on release
  pressed := rbtns[0,1]; // pressed tracks button 1

  leds := data_out0 | data_out1 | data_out2 | data_out3 ;

  always {

    addr    = cnt == 0 ? (addr + 1) : addr;
    wenable = 0;
    cnt     = cnt + 1;
  }

}
