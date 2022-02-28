circuitry take_width(input dat, output width) {
                    //     ^^^ Be careful: this must not reference a variable in the scope
                    //         where `take_width` is instantiated!
  width = widthof(dat);
}

algorithm main(output uint$NUM_LEDS$ leds) {
  uint20 data  = uninitialized;
  uint6  width = uninitialized;

  (width) = take_width(data);

  __display("WIDTH: %d", width);
}
