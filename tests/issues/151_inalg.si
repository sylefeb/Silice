group gr {
  uint8 data = 0
}

algorithm f(gr gio { input data }) {
  gio.data := 0;
}

algorithm main(output uint8 leds) {
  gr gio;
  f f(gio <:> gio);
}
