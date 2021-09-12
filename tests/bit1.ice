algorithm wait()
{
  int22 w = 0;

loop:
  w = w + 1;
  if (w != 0) { goto loop; } else {}
}

algorithm main(output int8 led)
{
  wait w;
  int3 i = 3b0;
  int8 myled = 0;
  
  led := myled;
  
loop:
  myled[i,1] = ~myled[i,1];
  i = i + 1;
  () <- w <- ();
  goto loop;
  
}
