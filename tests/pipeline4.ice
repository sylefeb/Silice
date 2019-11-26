algorithm main()
{
  uint8  v = 10;

  subroutine test(input uint8 a) {
    uint8  i = 0;
    uint8  b = 0;
    uint64 o = 0;
    while (i < 8) { // the while will stop too early
  
    {
      a = a + 1;
    } -> {
      b = a + 10;
    } -> {
      o[i*8,8] = b;
    }

    i = i + 1;   
    
    }
    return; 
 }
 
}
