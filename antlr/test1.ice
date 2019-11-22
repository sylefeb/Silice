
algorithm main(output uint8 foo)
{
  uint8 a = 0;
  uint8 b = 0;
  uint8 c = 0;

  uint8 i = 0;

  while (i < 16) {

	  {
		a = i;
	  } -> {
		b = a + 1;
	  } -> {
		c = b + 1;
		foo = foo | c;
	  }

  }
}
