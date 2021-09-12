// MIT license, see LICENSE_MIT in Silice repo root

algorithm main(
  input  uint$NUM_BTNS$ btns,
  output uint$NUM_LEDS$ leds)
{

  uint$NUM_BTNS$ reg_btns = 0;
  
  reg_btns ::= btns; // register btns (it is an async input)
  
  // leds track btns
  while (1) {
    leds = reg_btns;
  }

}
