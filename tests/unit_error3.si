// units, subroutines cannot be declared outside the algorithm block
// (recall subroutines can be globally defined however)
unit main(output uint8 leds)
{
  uint24 count = 0;

  subroutine inc(input uint24 a,output uint24 b) // error
  {
    b = a + 1;
  }

  always_before {
    __display("count = %d",count);
    if (count == 15) { __finish(); }
  }

  algorithm {
    while (1) {
      (count) <- inc <- (count);
    }
  }

}
