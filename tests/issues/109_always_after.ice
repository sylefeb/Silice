algorithm main(output uint8 leds)
{

  uint8 test(0);
  uint8 a(33);

  always_before {
    leds = test;
  }

  always_after {
    test = a + 1;
  }
  
  while (1) {
    a = a + 1;
  }
}

