// Sylvain Lefebvre; simple parallel division; 2019-10-09
// any width version; see divint.ice for more info

// Returns largest positive/negative int on div by zero
//
// == Requires ==
// div_width to be set to the desired bitwidth.
// for div_width = W the algorithm is named divW,
// e.g. div_width = 16 produces algorithm div16
//
// == Options ==
// div_unsigned : unsigned only
// div_shrink   : allows to reduce size at the expense of perf.
//    0 => default, use all stages
//    1 => one stage every two
//    2 => one stage every four
// ...
// at worst the algorithm becomes a loop adding
// den until it exceed num, resulting in worst performance
// but smallest synthesized size

$$if not div_shrink then
$$  div_shrink = 0
$$end

$$if div_width > 64 then
error('pre-processor constants cannot exceed 64 bits')
$$end

// use pre-processor to generate all comparators
$$for i = 0,div_width-2 do
algorithm mul_cmp$div_width$_$i$(
   input   uint$div_width$ num,
   input   uint$div_width$ den,
   output! uint1 beq)
<autorun>   
{
  uint$div_width+1$ nk = 0;
  always {
    nk  = (num >> $i$);
    beq = (nk > den);
  }
}
$$end

// division algorithm
algorithm div$div_width$(
  input  int$div_width$ inum,
  input  int$div_width$ iden,
  output int$div_width$ ret)
{
$$for i = 0,div_width-2 do
  uint1 r$i$ = 0;
$$end

  uint$div_width$ reminder = 0;

  uint1 num_neg = 0;
  uint1 den_neg = 0;
  
  uint$div_width$ num = 0;
  uint$div_width$ den = 0; 

  uint$div_width$ concat = 0;

  // instantiate comparators
$$prev = 0
$$K={}
$$for i = 0,div_width-2 do
$$if (i % (2^div_shrink)) == 0 then 
$$prev = i
$$K[i] = i
  mul_cmp$div_width$_$i$ mc$i$(num <:: reminder, den <:: den, beq :> r$i$);
$$else
$$K[i] = prev
  mul_cmp$div_width$_$prev$ mc$i$(num <:: reminder, den <:: den, beq :> r$i$);
$$end
$$end

  // deal with sign (den)
$$if not div_unsigned then
  if (iden < __signed(0)) {
    den_neg = 1;
    den = - iden;
  } else {
    den = iden;
  }
$$else
  den = iden;
$$end

  // deal with sign (num)
$$if not div_unsigned then
  if (inum < __signed(0)) {
    num_neg = 1;
    num = - inum;
  } else {
    num = inum;
  }
$$else
  num = inum;
$$end

$$if (MOJO or ULX3S) and div_width >= 24 then
++: // add step to fit the Mojo 100MHz timing
$$end

  // early exit on trivial cases
  if (den > num) {
    ret = 0;
    goto done;
  }
  if (den == num) {
    ret = 1;
    goto done;
  }
  if (den == 0) {
    // div by zero, returns largest positive/negative
$$ones=''
$$for i=1,div_width-1 do
$$ ones = ones .. '1'
$$end
    if (num_neg ^ den_neg) {
      ret = $div_width$b1$ones$;
    } else {
      ret = $div_width$b0$ones$;
    }
    goto done;
  }

  reminder = num;
  ret      = 0;

  while (reminder >= den) {
  
    // perform assignment based on occurring case
    
    // produce a vector from the comparators
    // it has a one-hot pattern like 0...010...0
$$concat='{'
$$for i = 0,div_width-3 do 
$$  concat = concat..'!r'..(div_width-2-i)..'&&r'..(div_width-2-i-1)..',' end
$$concat=concat..'1b0}'
    concat = $concat$;
    // switch base on this number (NOTE: could be a onehot switch)
    switch(concat) {
$$for c = 0,div_width-2 do
$$ s='' .. (div_width) .. 'b'
$$ for i = 0,div_width-2 do if i==c then s=s..'1' else s=s..'0' end end
$$ s=s..'0'
      case $s$: {
        ret      = ret      + (1<<$K[div_width-2-c]$);
        reminder = reminder - (den << $K[div_width-2-c]$);
      }
$$end      
// last case where 'concat' becomes all 0s
$$ s='' .. (div_width) .. 'b'
$$ for i = 0,div_width-1 do s=s..'0' end
      case $s$: {
        ret      = ret      + (1<<$K[0]$);
        reminder = reminder - (den << $K[0]$);
      }
      default: {
        // should never happen
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
