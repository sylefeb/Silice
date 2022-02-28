algorithm test( output uint8 v ) <autorun> {
  uint8 i = 100;
  v := i;
  while (1) {
    i = i + 1;
  }
}

algorithm main(output uint8 leds)
{
  test t;

  leds := t.v;

  // t <- (); // should trigger an error [ok]

  __display("leds = %d",leds);
++:
  __display("leds = %d",leds);
++:
  __display("leds = %d",leds);
++:
  __display("leds = %d",leds);
++:
  __display("leds = %d",leds);

  __finish();
}
