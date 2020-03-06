
// integer multiplication
$$mul_width = 16
$include('../common/mulint_pipe_any.ice')

algorithm main()
{
  int16  m0      = 0;
  int16  m1      = 0;
  int16  result  = 0;
  
  mulpip16 mul;
  
  // bind pipeline in/out
  result  := mul.ret;
  mul.im0 := m0;
  mul.im1 := m1;

  // not using a loop for easier understanding
  // each ++ let a cycle pass, after 5 cycles
  // the output is available
  
  m0 = 2;
  m1 = 3;
  $display("%d * %d = ...",m0,m1);  
++: // 1
  m0 = m0 + 1;
  m1 =-m1 - 1;
  $display("%d * %d = ...",m0,m1);  
++: // 2
  m0 = m0 + 1;
  m1 =-m1 + 1;
  $display("%d * %d = ...",m0,m1);  
++: // 3
  m0 = m0 + 1;
  m1 =-m1 - 1;
  $display("%d * %d = ...",m0,m1);  
++: // 4
  m0 = m0 + 1;
  m1 =-m1 + 1;
  $display("%d * %d = ...",m0,m1);  
++: // 5
  m0 = m0 + 1;
  m1 =-m1 - 1;
  $display("%d * %d = ...",m0,m1);  
++:
  $display("... = %d",result);  
++:
  $display("... = %d",result);  
++:
  $display("... = %d",result);  
++:
  $display("... = %d",result);  
++:
  $display("... = %d",result);  
++:
  $display("... = %d",result);  
++:

}
