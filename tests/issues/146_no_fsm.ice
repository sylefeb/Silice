
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

algorithm main(output uint8 leds)
{
  foo f;
  always {
	  leds = f.v;
	}
}
