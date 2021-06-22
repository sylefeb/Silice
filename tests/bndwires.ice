import('bndwires.v')

algorithm foo(input uint8 v,output uint8 o) {
  always {
    o = v;
  }
}

algorithm main(output uint8 leds)
{
  uint8 i(0);
	uint8 t(0);
	uint8 o(0);
  uint8 w <: i;

  //vfoo f1(v <:: t,o :> o);// error
	//vfoo f1(v <:: w,o :> o);// error

  // foo  f1(v <:: i,o :> t); // error (dbl binding)
	vfoo f1(v <:: i,o :> t); // error (dbl binding)
	
  foo f2(v <:: i,o :> t); // t bound
	
  //foo f(v <:: t,o :> o); // error
	//foo f(v <:: w,o :> o); // error
	
	leds := o;	
	i    := i + 1;
	
	
}
