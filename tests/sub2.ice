algorithm passthrough(input uint8 i,output uint8 o)
{
  o = i;
}

algorithm main(output uint8 led)
{ 
  int8 a = 0;
  int8 b = 0;
  int8 c = 0;

  passthrough p0;

  subroutine test(reads a)
	p0.i = a + 2;
    return;

  a = 1;
  b = 2;
  () <- test <- ();
  a = a + 5;
  () <- test <- ();
}
