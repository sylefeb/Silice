algorithm main()
{

  int8 a = 10;
  int8 b = 1;
  
  while (a > 0) {
    a = a - 1;
    if (a == 5) {
      break;
      b = 2;
    }
    while (b != 10) {
      b = b + 3;
      if (b == 15) {
        break;
      }
    }
  }

}