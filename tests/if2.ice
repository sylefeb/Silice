algorithm main()
{
  int8 data = 0;
  int8 a = 0;
  int8 b = 1;

  data = 1;
  a = 0;
  b = a+1;

  if (data == 0) {
    a = 1;
    if (data == 5) {
      a = a*2+1;
    }
    if (b == 0) {
      a = 3;
      goto g30;
    } else {
gtest:
      a = 4;
    }
  } else {
    a = 2;
  }

  goto skip;
g30:
  a = 30;
  goto gtest;
skip:

}
