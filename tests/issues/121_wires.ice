algorithm foo(input uint8 i,output uint8 o)
{
  o = i;
}

algorithm main(output uint8 leds)
{

  uint8 i(0);
  uint1 a := i == 1;
  uint8 b := a + 1;
  uint8 c(0);
  
  foo f(i <: b, o :> c);
  
  __display("c %b",c);

}
