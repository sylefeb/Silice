algorithm main(output uint8 v,input uint8 b)
{

  uint8 a = 0;

  v := b;

  always {
    v = a;
    if (b == 0) {
      v = 5;
    }
  }
  
}
