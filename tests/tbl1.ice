algorithm wait()
{
  int22 w = 0;
loop:
  w = w + 1;
  if (w != 0) { goto loop; }
}

algorithm main(output int8 led)
{
  wait w;
  int8 tbl[4] = {21,42,84,168};
  int2 i = 0;
  int8 myled = 0;
  
  led := myled;
  
loop:
  i = i + 1;
  myled = tbl[i];
  () <- w <- ();
  goto loop;
  
}
