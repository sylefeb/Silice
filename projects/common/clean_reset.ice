// SL 2020-10-25

algorithm clean_reset(  
  output uint1 out
) <autorun> {
  uint4  trigger = 15;
  always {
    out     = trigger[0,1];
    trigger = trigger >> 1;
  }
}
