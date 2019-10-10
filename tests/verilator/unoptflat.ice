
algorithm div(input uint8 num,output uint8 ret)
{
  $display("****** div %d",num);
  ret = num;
}

algorithm main()
{

  uint8 num = 231;
  uint8 res = 0;
/*
  div div0(
    num <: num,
    ret :> outv
  );
*/
  
  div div0;
  (res) <- div0 <- (num);

/*
  while (res < 5) {
    $display("****** %d",res);
    res = res + 1;
  }
*/
}


