// Sylvain Lefebvre; simple parallel division; 2019-10-09
// any width version; see divint.ice for more info

// == Requires ==
// div_width to be set to the desired bitwidth.
// for div_width = W the algorithm is named divW,
// e.g. div_width = 16 produces algorithm div16
// == Options ==
// div_unsigned : unsigned only
// div_shrink   : allows to reduce size at the expense of perf.
//    0 => default, use all stages
//    1 => default, one stage every two
//    2 => default, one stage every four
// ...
// at worst the algorithm because a loop adding
// den until it exceed num, resulting in worst performance
// but smallest synthesized size

$$if not div_shrink then
$$  div_shrink = 0
$$end

algorithm mul_cmp$div_width$(
   input   uint$div_width$ num,
   input   uint$div_width$ den,
   input   uint$div_width$ k,
   output  uint1 above)
<autorun>   
{
  uint$div_width+1$ th   = 0;
  uint$div_width+1$ dk   = 0;

  th = (1<<($div_width$-k));
  
  while (1) {
    dk = (den << k);
    if (den > th) {
      above = 1;
    } else {
      above = (num < dk);
    }
  }
}

algorithm div$div_width$(
  input  int$div_width$ inum,
  input  int$div_width$ iden,
  output int$div_width$ ret)
{
$$prev = 0
$$for i = 0,div_width-2 do
  uint$div_width$ k$i$ =
$$if (i % math.pow(2,div_shrink)) == 0 then 
$$prev = i
   $i$;
$$else
  $prev$;
$$end
  uint1 r$i$ = 0;
$$end

  uint$div_width$ reminder = 0;

  uint1 num_neg = 0;
  uint1 den_neg = 0;

  uint$div_width$ num = 0;
  uint$div_width$ den = 0; 
  
$$for i = 0,div_width-2 do
  mul_cmp$div_width$ mc$i$(num <: reminder, den <: den, k <: k$i$, above :> r$i$);
$$end

$$if not div_unsigned then
  if (iden < 0) {
    den_neg = 1;
    den = - iden;
  } else {
    den = iden;
  }
$$else
  den = iden;
$$end

$$if not div_unsigned then
  if (inum < 0) {
    num_neg = 1;
    num = - inum;
  } else {
    num = inum;
  }
$$else
  num = inum;
$$end

$$if MOJO and div_width == 32 then
++: // add step to fit the Mojo 100MHz timing at 32 bits
$$end

  if (den > num) {
    ret = 0;
    goto done;
  }
  if (den == num) {
    ret = 1;
    goto done;
  }
  if (den == 0) {
    ret = 0;
    goto done;
  }

  reminder = num;

  while (reminder >= den) {

    // assign ret/reminder from previous iteration
//    reminder = reminder_tmp;

    // wait for all multiply-compare in parallel
// ++:

    // perform assignment based on occuring case
$$concat='{'
$$for i = 0,div_width-3 do concat=concat..'r'..(div_width-2-i)..',' end
$$concat=concat..'r0}'
    switch($concat$) {
      // NOTE: cannot use reminder directly, a combinational loop would be created
$$for c = 0,div_width-2 do
$$ s='' .. (div_width-1) .. 'b'
$$ for i = 0,div_width-2 do if i<c then s=s..'1' else s=s..'0' end end      
      case $s$: {
        ret = ret + (1<<k$div_width-2-c$);
        reminder = reminder - (den << k$div_width-2-c$);
      }
$$end      
      default: {
        // should never happen
        reminder = 0;
      }
    }

  }

done:

$$if not div_unsigned then
  if (num_neg ^ den_neg) {
    ret = - ret;
  }
$$end
  
}

