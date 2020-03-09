// Sylvain Lefebvre; simple parallel multiplication; 2019-12-02
//
// Why? The goal is to achieve a multi-cycle multiplication
// with small combinational chains
//

// find out power of 2 of mul_width
$$mul_width_pow2=0
$$tmp = mul_width
$$while tmp > 1 do
$$  mul_width_pow2 = mul_width_pow2 + 1
$$  tmp = math.floor(tmp/2)
$$end
$$if 2^mul_width_pow2 ~= mul_width then
$$  error('mul_width is not a power of 2')
$$end
$$ print('generating multiplier for width ' .. 2^mul_width_pow2)

algorithm mul$mul_width$(
  input  int$mul_width$ im0,
  input  int$mul_width$ im1,
  output int$mul_width$ ret)
{
$$for l = 1,mul_width_pow2 do
$$  n = 2^(l-1)
$$  for i = 0,n-1 do
  uint$mul_width$ sum_$l$_$i$ = 0;
$$  end
$$end

  uint$mul_width$ m0 = 0;
  uint$mul_width$ m1 = 0;
  uint1 m0_neg = 0;
  uint1 m1_neg = 0;
  
  if (im0 < 0) {
    m0_neg = 1;
    m0 = - im0;
  } else {
    m0 = im0;
  }
  
  if (im1 < 0) {
    m1_neg = 1;
    m1 = - im1;
  } else {
    m1 = im1;
  }

$$if MOJO and mul_width == 32 then
++: // add step to fit the Mojo 100MHz timing at 32 bits
$$end

// generate leaves (shifts)
$$l = mul_width_pow2
$$n = 2^(l-1)
$$for i = 0,n-1 do
  switch (m1[$i*2$,2]) {
  case 2b00: { }
  case 2b10: { sum_$l$_$i$ = m0 << $i*2+1$; }
  case 2b01: { sum_$l$_$i$ = m0 << $i*2$; }
  case 2b11: { sum_$l$_$i$ = (m0 << $i*2$) + (m0 << $i*2+1$); }
  }
$$end

// generate reduction (adders)
$$for l = mul_width_pow2-1,1,-1 do
++:
$$  n = 2^(l-1)
$$  for i = 0,n-1 do
  sum_$l$_$i$ = sum_$l+1$_$i*2$ + sum_$l+1$_$i*2+1$;
$$  end
$$end

  if (m0_neg ^ m1_neg) {
    ret = - sum_1_0;
  } else {
    ret = sum_1_0;
  }  

}

