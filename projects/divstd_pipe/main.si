// @sylefeb 2019
// https://github.com/sylefeb/Silice
// MIT license, see LICENSE_MIT in Silice repo root

$$div_width      = 16
$$div_width_pow2 = clog2(div_width)

// division
algorithm div$div_width$(
  input  uint$div_width$ num,
  input  uint$div_width$ den,
  output uint$div_width$ ret)
{
  uint$div_width+1$ ac = uninitialized;
  uint$div_width+1$ rt = uninitialized;
  uint$div_width$   dn = uninitialized;
  always { // always active
    {
      ac   = {{$div_width-1${1b0}},num[$div_width-1$,1]};
      rt   = {num[0,$div_width-1$],1b0};
      dn   = den;
  $$for i=1,div_width do
    } -> { // next pipeline stage
      uint$div_width+1$ diff <:: ac - dn;
      if (diff[$div_width$,1] == 0) { // positive
        ac  = {diff[0,$div_width-1$],rt[$div_width-1$,1]};
        rt  = {rt  [0,$div_width-1$],1b1};
      } else {
        ac  = {ac  [0,$div_width-1$],rt[$div_width-1$,1]};
        rt  = {rt  [0,$div_width-1$],1b0};
      }
      $$if i == div_width then
      ret = rt;
      $$end
  $$end
    }
  }
}

algorithm main(output uint8 leds)
{
  uint8  i = 0;
  uint8  cycle = 0;

  div$div_width$ div0;

  always_after { cycle = cycle + 1; }

  div0.num = 20043;
  div0.den = 1;
  while (i != $div_width*2$) {
    if (i[$div_width_pow2$,1]) {
      __display("[cycle %d]                 ... =",cycle,div0.ret);
    } else {
      __display("[cycle %d] %d / %d = ...",cycle,div0.num,div0.den);
      div0.den = div0.den + 1;
    }
    i = i + 1;
  }

  leds = div0.ret[0,8];
}
