algorithm main(output uint8 leds) {

  subroutine f(
    input uint1 bool,
		output uint1 foo
  ) {
    uint1 x <: bool;
++:
		foo = x; // was in error, now produces 'correct' verilog
		// however bool is not detected as a flip-flop through x
		// should it be, or not?
  }

  (leds) <- f <- (0);

}
