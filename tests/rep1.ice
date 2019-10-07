algorithm main(output int8 led)
{
  int8 tbl[8] = {1,2,4,8,16,32,64,128};
  int8 myled = 0;
  
  led := myled;

  8x {
    tbl[__id] = __id;
  }

  8x {
    if ((__id & 1) == 0) {
      tbl[__id] = 0;
    }
  }
  
}
