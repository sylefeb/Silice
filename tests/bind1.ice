algorithm foo(output uint16 cnt=0)
{
  always { cnt = cnt + 1; }
}

algorithm bla(input uint16 a,output uint16 b)
{
  b = a;
}

algorithm main(input uint8 tmp,output uint8 leds)
{
  foo f;
	
	uint16 test1 <:: tmp;
	uint16 test3 <:  tmp;
	uint16 test2 <:: test3 + f.cnt;
	
	// bla bla1(a <:: test1); // error: ok
	
	while (1) {
		__display("%d",test2);
		if (test2 == 512) { __finish(); }
  }

}
