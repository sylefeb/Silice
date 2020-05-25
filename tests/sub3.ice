subroutine never_called(input uint8 i,output uint8 o,writes a)
{
  a = i;
  o = i;
}

algorithm main(output uint8 led)
{ 
  int8 a = 0;
  int8 v = 0;

  led = a;
}
