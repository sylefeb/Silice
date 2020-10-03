
algorithm main(output uint$NUM_LEDS$ leds)
{
  uint32 cnt = 0;
  
  // track msb of the counter
  leds := cnt[$32-NUM_LEDS$,$NUM_LEDS$];

  // count!
  while (1) {    
    cnt  = cnt + 1;
  }
}
