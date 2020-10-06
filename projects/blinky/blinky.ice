
algorithm main(output uint$NUM_LEDS$ leds)
{
  uint32 cnt = 0;
  
  // track msb of the counter
  leds := cnt[$32-NUM_LEDS$,$NUM_LEDS$];

$$if SIMULATION then
  while (cnt < 256) {   
$$else
  while (1) {   
$$end
    cnt  = cnt + 1;
  }

}
