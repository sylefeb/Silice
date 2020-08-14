algorithm main(output uint8 led)
{
  uint1 a = 0;
   
  led = 1;
++:
  if (a) {
  led = 2;
  } else {
  led = 3;
  }
++:  
  led = 4;
  
}