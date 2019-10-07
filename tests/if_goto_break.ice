algorithm main()
{
  int8 a = 0;
  int8 b = 1;

  if (b == 0) {
    if (b == 1) {
      a = 1;
      goto next;
      a = 3;
    }
    a = 2;
  }
next:

  while (a == 1) {
    if (a == 2) {
      b = 3;
      break;
    } else {
      a = 5;
    }
    b = 1;
  }

}
