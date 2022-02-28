unit main(output uint8 leds)
{

  algorithm{
    uint24 count = 0;
    while (1) {
      count = count + 1;
    }
  }

  always_after {
    leds = count[0,8];
  }

}
