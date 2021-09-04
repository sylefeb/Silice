bitfield test{
  uint1 one,
  uint7 seven
}

algorithm main(output uint8 leds)
{
  uint8 tbl[16] = {pad(1)};
++:  
  tbl[0][1,7] = 1; // ok
++:  
  test(tbl[0]).seven = 1; // failed
  
}
