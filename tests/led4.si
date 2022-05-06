algorithm orab(input int8 a,input int8 b,output int8 v)
{
  v = a | b;
}

algorithm wait()
{
  int18 w = 0;
loop:
  w = w + 1;
  if (w != 0) { goto loop; }
}

algorithm main(output int8 led)
{
  orab  o;
  wait  w;

  int8 a = 1;
  int8 b = 128;
  int8 myled = 0;
  
  led := myled;
  
loop:
  () <- w <- ();
  (myled) <- o <- (a,b);
  () <- w <- ();
  myled = 0;
  a = (a << 1);
  b = (b >> 1);
  if (a == 0) { a = 1; }
  if (b == 0) { b = 128; }
  goto loop;
}
