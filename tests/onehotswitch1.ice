
algorithm main(output uint8 leds)
{

  uint4 num = 1;
  uint8 res = 0;

  while (~num[3,1]) {

    onehot (num) {
      case 0:  { res = 10; }
      case 1:  { res = 20; }
      case 2:  { res = 30; }
    }
    num = num << 1;
    __display("res = %d",res);
  }
}

