$$div_width = 8
$$div_unsigned = 1
$include('../../projects/common/divint_std.ice')

$$INPUT="uint" .. div_width
$$OUTPUT=INPUT
$$DIV="div" .. div_width

algorithm main(output uint8 leds)
{
  __display("OK");
}

$$if FORMAL then
// This macro is automatically defined by the `formal` board.

/////////////// Properties of division: //////////////

// right identity: x / 1 = x
algorithm# right_identity(
  input $INPUT$ x
) <#mode=bmc & tind, #depth=20>
{
  $OUTPUT$ r1 = uninitialized;
  $DIV$ div1;
  $INPUT$ x_ <:: x;

  #stableinput(x);

  (r1) <- div1 <- (x_, 1);

  #assert(r1 == x_);
}

// left zero: 0 / x = 0
algorithm# left_zero(
  input $INPUT$ x
) <#mode=bmc & tind, #depth=20>
{
  $OUTPUT$ r1 = uninitialized;
  $DIV$ div1;

  #stableinput(x);
  #assume(x != 0);

  (r1) <- div1 <- (0, x);

  #assert(r1 == 0);
}

// nullability: x / x = 1
algorithm# nullability(
  input $INPUT$ x
) <#mode=bmc & tind, #depth=20>
{
  $OUTPUT$ r1 = uninitialized;

  $DIV$ div1;

  #stableinput(x);
  #assume(x != 0);

  (r1) <- div1 <- (x, x);

  #assert(r1 == 1);
}

// : x / y = 0 iff |y| > |x|
algorithm# some_property(
  input $INPUT$ x,
  input $INPUT$ y
) <#mode=bmc & tind, #depth=20>
{
  $OUTPUT$ r1 = uninitialized;
  $DIV$ div1;

  #stableinput(x);
  #stableinput(y);
  #assume(y != 0);

  (r1) <- div1 <- (x, y);

$$if div_unsigned then
  #assert(y > x ? r1 == 0 : 1);
$$else
  #assert({0b0, y[0, $div_width-1$]} > {0b0, x[0, $div_width-1$]} ? r1 == 0 : 1);
$$end
}


$$end
