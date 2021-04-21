algorithm intensity(output uint1 pwm_bit)
{
  uint16 ups_and_downs = 16b1110000000000000;

  pwm_bit       := ups_and_downs[0,1];
  ups_and_downs := {ups_and_downs[0,1],ups_and_downs[1,15]};
}

algorithm main(output uint5 leds)
{
  intensity less_intense;

  uint26 cnt = 0;
  
  leds := cnt[21,5] & {5{less_intense.pwm_bit}};
  cnt  := cnt + 1;  
}
