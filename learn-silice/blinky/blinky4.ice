algorithm wait(input uint32 delay)
{
  uint32 cnt = 0;
  while (cnt != delay) {
    cnt = cnt + 1;
  }
}

algorithm blink_sequence(output uint1 led,input uint3 times)
{
  wait waste_cycles;

  uint3 n = 0;
  while (n != times)  {
    // turn LEDs on
    led = 1;
    () <- waste_cycles <- (3000000);
    // turn LEDs off
    led = 0;
    () <- waste_cycles <- (3000000);
    n = n + 1;
  }
  // long pause
  () <- waste_cycles <- (50000000);
}


algorithm main(output uint5 leds)
{
  blink_sequence s0;
  blink_sequence s1;
  blink_sequence s2;
  blink_sequence s3;
  blink_sequence s4;

  leds := {s4.led,s3.led,s2.led,s1.led,s0.led};

  while (1) {
    s0 <- (1);
    s1 <- (2);
    s2 <- (3);
    s3 <- (4);
    s4 <- (5);
    // wait for longest to be done
    () <- s4;
  }

}
