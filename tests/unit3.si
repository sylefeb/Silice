// units can use the := syntax
// goes before anything else
unit main(output uint8 leds)
{
  uint24 count = 100;
  uint8  test(0);

  test := count[1,8];

  always_before {
    if (count == 132) { __finish(); }
    __display("count = %d test=%d",count,test);
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
