
algorithm alg(input uint8 num,output uint8 ret)
{
  ret = num;
}

algorithm main()
{

  uint8 num = 231;
  uint8 res = 0;

  alg alg0;
//  alg alg0(num <: num);
//  alg alg0(ret :> res);
//  alg alg0(num <: num,ret :> res);

  (res) <- alg0 <- (num);
//  (res) <- alg0 <- ();
//  alg0 <- (num);
//  alg0 <- ();

  $display("res = %d",res);
}

