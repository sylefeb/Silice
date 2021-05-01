import('ice40_warmboot.v')

algorithm main(output uint5 leds,input uint3 btns)
{                                        
  uint28 cnt(0);
  uint3  rbtns(0);
  uint1  pressed(0);

  uint1  boot(0);
	uint2  slot(0);
  ice40_warmboot wb(boot <: boot,slot <: slot);
  	
	slot     := 2b01; // go to blinky2

  rbtns  ::= btns;  // register input buttons
	boot    := boot | (pressed & ~rbtns[0,1]); // set high on release
	pressed := rbtns[0,1]; // pressed tracks button 1
	
  leds     := cnt[23,1] ? 5b00001 : 5b0000;
	//                      ^^^^^^^ red LED blink
  cnt      := cnt + 1;

}
