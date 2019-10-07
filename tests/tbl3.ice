algorithm test(input int8 tbl[4],output int8 v[4])
{
  4x {
    v[__id] = tbl[3-__id];
  }
}

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
  test t;
  int8 tbl[4] = {21,42,84,168};
  int8 myled = 0;
  
  led := myled;
  
loop:
  
  (tbl) <- t <- (tbl);
  myled = tbl[0];
  () <- w <- ();
  
  goto loop;
  
}
