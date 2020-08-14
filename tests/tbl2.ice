algorithm test(input int8 tbl[8],output int8 v)
{
  v = tbl[0] | tbl[1] | tbl[2] | tbl[3] 
    | tbl[4] | tbl[5] | tbl[6] | tbl[7];
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
  test tst;
  int8 tbl[8] = {1,2,4,8,16,32,64,128};
  int8 myled = 0;
  int8 i = 0;
  
  led := myled;

loop:

   i = 0;
   
fori:
  myled = tbl[i];
  //() <- w <- ();
  i = i + 1;
  if (i < 8) {
    goto fori;
  }
  
  (myled) <- tst <- (tbl);
  //() <- w <- ();
  
  goto loop;
  
}
