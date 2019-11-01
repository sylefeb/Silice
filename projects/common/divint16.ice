// Sylvain Lefebvre; simple parallel division; 2019-10-09
// 16 bit version; see divint.ice for more info

$$div_width=16

algorithm mul_cmp$div_width$(
   input   uint$div_width$ num,
   input   uint$div_width$ den,
   input   uint$div_width$ k,
   output! uint1 above)
{
  uint17 th   = 0;
  uint17 dk   = 0;

  th = (1<<(16-k));
  dk = (den << k);

  if (den > th) {
    above = 1;
  } else {
    above = (num < dk);
  }
}

algorithm div$div_width$(input int$div_width$ inum,input int$div_width$ iden,output! int$div_width$ ret)
{
$$for i = 0,div_width-2 do
  uint$div_width$ k$i$ = 0;
  uint1 r$i$ = 0;
$$end

  uint$div_width$ reminder = 0;
  uint$div_width$ reminder_tmp = 0;

  uint1 num_neg = 0;
  uint1 den_neg = 0;

  uint$div_width$ num = 0;
  uint$div_width$ den = 0; 
  
$$for i = 0,div_width-2 do
  mul_cmp$div_width$ mc$i$(num <: reminder, den <: den, k <: k$i$, above :> r$i$);
$$end

  if (iden < 0) {
    den_neg = 1;
    den = - iden;
  } else {
    den = iden;
  }
  
  if (inum < 0) {
    num_neg = 1;
    num = - inum;
  } else {
    num = inum;
  }

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
$$for i = 0,div_width-2 do
    mc$i$ <- ();
$$end

++:

    // perform assignment based on occuring case
$$concat='{'
$$for i = 0,13 do concat=concat..'r'..(14-i)..',' end
$$concat=concat..'r0}'
    switch($concat$) {
      // NOTE: cannot use reminder directly, a combinational loop would be created
$$for c = 0,14 do
$$ s='15b'
$$ for i = 0,14 do if i<c then s=s..'1' else s=s..'0' end end      
      case $s$: {
        ret = ret + (1<<k$14-c$);
        reminder_tmp = reminder - (1<<k$14-c$)*den;
      }
$$end      
      default: {
        // should never happen
        reminder_tmp = reminder;
      }
    }

  }

done:

  if (num_neg ^ den_neg) {
    ret = - ret;
  }
}

