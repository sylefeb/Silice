import('../../common/ice40_warmboot.v')

algorithm main(output uint5 leds,input uint3 btns)
{                      
  uint3  rbtns(0);
  uint1  pressed(0);

  uint1  boot(0);
  uint2  slot(0);
  ice40_warmboot wb(boot <: boot,slot <: slot);

  slot    := 2b00; // goes back to bootloader (bitstream 0)
                   // the bistream vector in slot 1 is hotswapped by bootloader

  rbtns  ::= btns;  // register input buttons
  boot    := boot | (pressed & ~rbtns[0,1]); // set high on release
  pressed := rbtns[0,1]; // pressed tracks button 1

  leds    := $LEDs$;

}
