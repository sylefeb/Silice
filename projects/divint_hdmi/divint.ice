// Sylvain Lefebvre; naive parallel division; 2019-10-09
//
// 231 / 17
// 
// 1*17=1 2*17=34 4*17=68 8*17=136 16*17=272 32*17=544 64*17=1088
//      0       0       0        0         1         1          1
// ret = 8
// num = 95
//
// 1*17=1 2*17=34 4*17=68 8*17=136 16*17=272 32*17=544 64*17=1088
//      0       0       0        1        1        1         1
// ret = 8+4
// num = 27
//
// 1*17=1 2*17=34 4*17=68 8*17=136 16*17=272 32*17=544 64*17=1088
//      0       0       0        1        1        1         1
// ret = 8+4+1
// num = 10
//
// done!  231/17 = 13

algorithm mul_cmp(input uint8 num,input uint8 den,input uint8 k,output uint1 above)
{
  uint9 th   = 0;
  uint9 dk   = 0;

  th = (1<<(8-k));
  dk = (den << k);

  if (den > th) {
    above = 1;
  } else {
    above = (num < dk);
  }
}

algorithm div(input uint8 num,input uint8 den,output uint8 ret)
{

  uint8 k0 = 0;
  uint8 k1 = 1;
  uint8 k2 = 2;
  uint8 k3 = 3;
  uint8 k4 = 4;
  uint8 k5 = 5;
  uint8 k6 = 6;

  uint1 r0 = 0;
  uint1 r1 = 0;
  uint1 r2 = 0;
  uint1 r3 = 0;
  uint1 r4 = 0;
  uint1 r5 = 0;
  uint1 r6 = 0;

  uint8 reminder = 0;

  uint8 reminder_tmp = 0;
  uint8 ret_tmp = 0;

  mul_cmp mc0(num <: reminder, den <: den, k <: k0, above :> r0);
  mul_cmp mc1(num <: reminder, den <: den, k <: k1, above :> r1);
  mul_cmp mc2(num <: reminder, den <: den, k <: k2, above :> r2);
  mul_cmp mc3(num <: reminder, den <: den, k <: k3, above :> r3);
  mul_cmp mc4(num <: reminder, den <: den, k <: k4, above :> r4);
  mul_cmp mc5(num <: reminder, den <: den, k <: k5, above :> r5);
  mul_cmp mc6(num <: reminder, den <: den, k <: k6, above :> r6);

  if (den > num) {
    ret = 0;
    goto done;
  }
  if (den == num) {
    ret = 1;
    goto done;
  }

  reminder = num;

  while (reminder >= den) {

    mc0 <- ();
    mc1 <- ();
    mc2 <- ();
    mc3 <- ();
    mc4 <- ();
    mc5 <- ();
    mc6 <- ();

++:

    // perform all compare assign in parallel
    // only one can be true; note the use of ret_tmp/reminder_tmp
    // to guarantee the verilog compiler does not serialize
    if (r1 && !r0) {
      ret_tmp = ret + (1<<k0);
      reminder_tmp = reminder - (1<<k0)*den;
    }
    if (r2 && !r1) {
      ret_tmp = ret + (1<<k1);
      reminder_tmp = reminder - (1<<k1)*den;
    }    
    if (r3 && !r2) {
      ret_tmp = ret + (1<<k2);
      reminder_tmp = reminder - (1<<k2)*den;
    }    
    if (r4 && !r3) {
      ret_tmp = ret + (1<<k3);
      reminder_tmp = reminder - (1<<k3)*den;
    }    
    if (r5 && !r4) {
      ret_tmp = ret + (1<<k4);
      reminder_tmp = reminder - (1<<k4)*den;
    }    
    if (r6 && !r5) {
      ret_tmp = ret + (1<<k5);
      reminder_tmp = reminder - (1<<k5)*den;
    }
    if (!r0 && !r1 && !r2 && !r3 && !r4 && !r5 && !r6) {
      ret_tmp = ret + (1<<k6);
      reminder_tmp = reminder - (1<<k6)*den;
    }

++:

    // now assign ret/reminder
    ret      = ret_tmp;
    reminder = reminder_tmp;

  }

done:

}
