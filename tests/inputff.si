algorithm alg(input uint8 i,output uint8 o)
{
  always { o = i; }
}

algorithm main(output uint8 leds)
{
  alg a;
  
  always { a.i = 2; }
  
  __display("alg.o = %d",a.o);
}
