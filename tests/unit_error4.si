// units, cannot have always and algorithm
unit main(output uint8 leds)
{
  uint24 count = 0;

  always {
    __display("count = %d",count);
    if (count == 15) { __finish(); }
  }

  algorithm {
    while (1) {
      count = count + 1;
    }
  }

}
