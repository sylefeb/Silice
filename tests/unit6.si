// units always_before/algorithm/always_after are optional
unit main(output uint8 leds)
{
  uint24 count = 100;

  always_before {
    if (count == 132) { __finish(); }
    __display("count = %d",count);
    count = count + 1;
  }

  always_after {
    leds = count[0,8];
  }

}
