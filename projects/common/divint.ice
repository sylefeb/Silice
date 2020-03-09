// Sylvain Lefebvre; simple parallel division; 2019-10-09
//
// 2019-10-12 Seems like I reinvented the division algorithm in:
//   Novel Methods of Integer Multiplication and Division 
//   1983 (!) https://archive.org/details/byte-magazine-1983-06/page/n363
//   see also http://techref.massmind.org/techref/method/math/muldiv.htm
// but with multiply-compare done in parallel :-)
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
//

algorithm mul_cmp(
   input   uint8 num,
   input   uint8 den,
   input   uint8 k,
   output  uint1 above)
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

  reminder_tmp = num;

  while (reminder_tmp >= den) {

    // assign ret/reminder from previous iteration
    reminder = reminder_tmp;

    // run all multiply-compare in parallel
    mc0 <- ();
    mc1 <- ();
    mc2 <- ();
    mc3 <- ();
    mc4 <- ();
    mc5 <- ();
    mc6 <- ();

++:

    // perform assignment based on occuring case
    switch({r6,r5,r4,r3,r2,r1,r0}) {
      // NOTE: cannot use reminder directly, a combinational loop would be created
      case 7b0000000: {
        ret = ret + (1<<k6);
        reminder_tmp = reminder - (den<<k6);
      }
      case 7b1000000: {
        ret = ret + (1<<k5);
        reminder_tmp = reminder - (den<<k5);
      }
      case 7b1100000: {
        ret = ret + (1<<k4);
        reminder_tmp = reminder - (den<<k4);
      }
      case 7b1110000: {
        ret = ret + (1<<k3);
        reminder_tmp = reminder - (den<<k3);
      }
      case 7b1111000: {
        ret = ret + (1<<k2);
        reminder_tmp = reminder - (den<<k2);
      }
      case 7b1111100: {
        ret = ret + (1<<k1);
        reminder_tmp = reminder - (den<<k1);
      }
      case 7b1111110: {
        ret = ret + (1<<k0);
        reminder_tmp = reminder - (den<<k0);
      }
      default: {
        // should never happen
        reminder_tmp = reminder;
      }
    }

  }

done:

}

