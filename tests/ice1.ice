algorithm main(
  output uint1 led0,
  output uint1 led1,
  output uint1 led2,
  output uint1 led3,
  output uint1 led4
) {

  uint16 counter = 0;
  uint1  myled   = 0;

  led0 := myled;
  led1 := myled;
  led2 := myled;
  led3 := myled;
  led4 := myled;

  while (1 == 1) {
    counter = counter + 1;
    if (counter == 0) {
      myled = ~myled;
    }
  }
  
}
