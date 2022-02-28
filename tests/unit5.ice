// units always_before/algorithm/always_after are optional
unit main(output uint8 leds)
{
  uint24 count = 100;

  algorithm {
    while (1) {
      if (count == 132) { __finish(); }
      leds  = count[0,8];
      count = count + 1;
      __display("count = %d, leds = %b",count, leds);
    }
  }

}
