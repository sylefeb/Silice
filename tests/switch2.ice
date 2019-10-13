
algorithm main()
{

  uint8 num = 0;
  uint8 res = 0;

  switch (num) {
  
  case 0:  { res = 42; }
  default: { goto skip; }
  
  }

  $display("res = %d",res);

  goto done;
  
skip:

  $display("skipped");
	
done:
}

