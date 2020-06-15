algorithm main(output uint8 led,input uint8 bar)
{
  uint8 w := bar;
  w = 1; // should trigger an error
  led = w;
}