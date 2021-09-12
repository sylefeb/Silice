algorithm main(output uint8 outp,input uint8 inp)
{

  uint1 active = 0;
  
  active = 1;
++:
  if (inp > 1) {
    if (inp < 5) {
    
    } else {
      active = 0;
    }  
  } else {
    if (inp < 5) {
    
    } else {
      active = 0;
    }  
  }
  
  outp = active; // active should be DQ
  
}