algorithm wait(input uint32 delay)
{
  uint32 cnt = 0;
  while (cnt != delay) {
    cnt = cnt + 1;
  }
}

algorithm main(output uint5 leds)
{
  wait waste_cycles;

  while (1) {
    uint3 n = 0;
    while (n != 5)  {
      // turn LEDs on
      leds = 5b11111;
      () <- waste_cycles <- (3000000);
      // turn LEDs off
      leds = 5b00000;
      () <- waste_cycles <- (3000000);
      n = n + 1;
    }
    // long pause
    () <- waste_cycles <- (50000000);
  }
}
