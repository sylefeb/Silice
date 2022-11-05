// units impose an order on always_before/algorithm/always_after blocks
unit main(output uint8 leds)
{
  uint24 count = 0;

  algorithm {
    subroutine inc(input uint24 a,output uint24 b)
    {
      b = a + 1;
    }
    while (1) {
      (count) <- inc <- (count);
    }
  }

  always_before { // should be /before/ the algorithm
    __display("count = %d",count);
    if (count == 15) { __finish(); }
  }

}
