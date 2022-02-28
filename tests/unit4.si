// units can have a single always block and still use the always assign :=
// goes before anything else
unit main(output uint8 leds)
{
  uint24 count = 0;

  leds := count[1,8];

  always {
    if (count == 132) { __finish(); }
    count = count + 1;
    __display("count = %d, leds = %d",count, leds);
  }
}
