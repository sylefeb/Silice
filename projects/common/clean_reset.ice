// SL 2020-10-25

algorithm clean_reset(  
  output uint1 out
) <autorun> {
  int8  trigger(8b10000000);
  always {
    out     = ~ trigger[0,1];
    trigger = trigger >>> 1;
  }
}
