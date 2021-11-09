algorithm main(output uint8 leds)
{
  uint7 init(127);

  __display("here 0");
  if ( ^init ) {
    __display("here 1");
  }
  __display("here 2");
}
