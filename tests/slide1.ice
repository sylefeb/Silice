algorithm main()
{
  uint8 a   = 0;
  uint8 tmp = 0;
  uint1 c1  = 0;
  uint1 c2  = 0;

++:
/*
  if (c1) { 	
    a = a - 1;
  }
  if (c2) {
    a = a + 10;
  }
*/
  if (c1) { 	
    tmp = a - 1;
  } else {
    tmp = a;
  }
  if (c2) {
    a = tmp + 10;
  } else {
    a = tmp;
  }

}

/*

  if (c1) { 	
    if (c2) {
      a = a - 1 + 10;
    } else {
      a = a - 1;
    }
  } else {
    if (c2) {
      a = a + 10;
    }
  }

*/