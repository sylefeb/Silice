
algorithm test(input uint8 i,output uint8 o)
{
  o = i;
}


algorithm main()
{
  uint8 a = 0;
  uint8 b = 0;
  
  test tst;
  
  b = a + 1;
  (a) <- tst <- (b);
  if (a == 2) {
    $display("a == 2");  
  }
++:
  a = a + 1;

}
