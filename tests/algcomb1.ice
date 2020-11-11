algorithm foo(
  input   uint1 i,
  output! uint1 o
) {
  o = i;  
}

algorithm main()
{

  uint1 a = 0;
  uint1 b = 0;
  
  foo f(
    i <: a,
    o :> b
  );
  
  a = b;

}