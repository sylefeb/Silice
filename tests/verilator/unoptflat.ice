algorithm div(input uint8 num,output uint8 ret)
{
  ret = num;
}

algorithm main(output uint8 outv)
{

  uint8 num = 231;

/*
  div div0(
    num <: num,
    ret :> outv
  );
*/
  
  div div0;
  (outv) <- div0 <- (num);

}

