algorithm main()
{
  uint8  i = 0;
  uint8  a = 255;
  uint8  b = 255;
  uint8  c = 255;
  uint64 o = 0;

  a = 0;
  while (i < 8 + 4) { // the while will stop too early
  
	// NOTE: always assign trickling for stage 0?
    // NOTE: write to trickling and set value at the end (last stage)?
    {
	  a = a + 1;
    } -> {
	  b = a + 10;
	} -> {
	  c = a + 2;
    } -> {
      o[i*8,8] = b;
    }

    i = i + 1;   
    
  }
 
  $display("%x",o);
 
}
