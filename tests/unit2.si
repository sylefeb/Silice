// units can have a single always block
unit main(output uint8 leds)
{
  uint24 count = 0;

  always {
    if (count == 132) { __finish(); }
    count = count + 1;
    __display("count = %d",count);
  }
}
