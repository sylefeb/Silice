
algorithm count(output uint8 v) <autorun>
{
  v = 0;
	while (1) {
	  v = v + 1;
	}
}

algorithm foo(output uint8 v)
{
  count cnt;
  always {
	  v = cnt.v;
	}
}

algorithm count2(output uint8 v)
{
  always {
	  v = v + 1;
	}
}

algorithm main(output uint8 leds)
{
  foo f;
	count2 c2;
  always {
	  leds = f.v | c2.v;
	}
}
