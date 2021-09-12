
algorithm main(output uint8 leds)
{

  uint8 v(0);  
  uint8 t <: v + 1;

++:
  leds = t;
  v    = v + 1;
  __display("leds %d v %d t %d",leds,v,t);

}