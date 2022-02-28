algorithm intensity(
  input  uint4 threshold,
  output uint1 pwm_bit)
{
  uint4 cnt = 0;

  pwm_bit  := (cnt <= threshold);
  cnt      := cnt + 1;
}

algorithm main(output uint5 leds)
{
  uint4  th = 0;
  uint1  pb = 0;
  intensity pulse(
    threshold <: th,
    pwm_bit   :> pb
  );

  uint20 cnt          = 0;
  uint1  down_else_up = 0;

  leds := {5{pb}};
  
  while (1) {
    if (cnt == 0) {      
      if (down_else_up) {
        if (th == 0) {
          down_else_up = 0;
        } else {
          th = th - 1;
        }
      } else {
        if (th == 15) {
          down_else_up = 1;
        } else {
          th = th + 1;
        }
      }
    }
    cnt = cnt + 1;
  }
}
