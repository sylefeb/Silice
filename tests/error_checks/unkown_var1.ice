import('reset_conditioner.v')

algorithm main(
  input int1  rst_n,
  output int8 led
  )
{
  int1 rst = 0;
  
  reset_conditioner rstcond(
    rcclk <: clk,
    in    <: rst_n,
    out  :> rst
  );
  
  int8 myled = 0;

  led := myled;
  
  if (rst != 0) {
    myled = 255;
  }
  
}
