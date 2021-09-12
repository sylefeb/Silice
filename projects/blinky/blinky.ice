// MIT license, see LICENSE_MIT in Silice repo root

algorithm main(output uint$NUM_LEDS$ leds) // $NUM_LEDS$ is replaced by the preprocessor,
{                                          // e.g. this becomes uint5 on the IceStick and IceBreaker
  uint28 cnt = 0; // 28 bits wide unsigned int

  // leds tracks the most significant bits of the counter
  leds := cnt[ widthof(cnt)-widthof(leds) , widthof(leds) ];

$$if SIMULATION then
  while (cnt < 256) { // if siumlation we perform only 256 cycles
$$else
  while (1) {         // if hardware, run forever
$$end
    cnt  = cnt + 1; // increase cnt (loops back to zero after overflow)
  }

}
