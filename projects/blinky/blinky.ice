algorithm main(output uint$NUM_LEDS$ leds)
{
  uint28 cnt = 0;
  
  // track msb of the counter
  leds := cnt[$28-NUM_LEDS$,$NUM_LEDS$];

  // count!
  while (1) {    
    cnt  = cnt + 1;
  }
}
