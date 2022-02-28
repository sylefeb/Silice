// units cannot mix an always block with always_before/algorithm/always_after
unit main(output uint8 leds)
{
  uint24 count = 100;

  always { // error: cannot have always, together with always_before/algorithm/always_after
    __display("count = %d",count);
  }

  algorithm {
    while (1) {
      count = count + 1;
    }
  }

  always_after {
    leds = count[0,8];
  }

}
