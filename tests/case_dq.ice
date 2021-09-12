algorithm main(output uint8 outp,input uint8 inp)
{

  uint8 a = uninitialized;
/*
  if (inp[0,1]) {
    a = 3;
  } else {

  }
*/  
  switch (inp)
  {
    case 0: {
      a = 1;
    }
    case 1: {
      a = 2;
    }
    default: {
      a = 3;
    }
  }

  outp = a;
  
}