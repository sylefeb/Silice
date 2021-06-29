algorithm main(output uint8 leds) 
{

  uint1 foo = 0;
	uint1 x <: foo;
	
	foo := 5;
	
++:
  
  leds = x;	

}
