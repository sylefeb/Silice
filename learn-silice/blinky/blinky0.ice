
algorithm main(output uint5 leds)
{
  uint28 cnt = 0;
  
  while (1) {
    leds = cnt[23,5];
    cnt  = cnt + 1;
  }
}
