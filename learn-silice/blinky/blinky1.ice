
algorithm main(output uint$NUM_LEDS$ leds)
{
  uint28 cnt = 0;
  
  // track msb of the counter
  leds := cnt[ widthof(cnt)-widthof(leds) , widthof(leds) ];

  // count
$$if SIMULATION then
  while (cnt < 256) { // if siumlation we perform only 256 cycles
$$else
  while (1) {         // in hardware, count forever (cnt loops back to zero after overflow)
$$end
    cnt  = cnt + 1;
  }

}
