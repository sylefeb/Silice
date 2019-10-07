
algorithm test(input int8 a,output int8 v)
{

}

algorithm main(output int8 led)
{
  int8 b = 0;

  test t0(
    v :> led,
	a <: b
  );

  // bla
  // bla

  test t1(
    v :> led,
	a <: missing
  );
}
