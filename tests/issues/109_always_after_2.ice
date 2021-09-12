algorithm main(output uint8 leds)
{
  uint8 a = 0;

  always_before {
    leds = a;
  }

  always_after {
    a = a + 1;
  }
  
  while (1) {  }
}

