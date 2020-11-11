// SL 2020-10-25

algorithm clean_reset(  
  output uint1 out
) <autorun> {
  uint8 counter       = 1;
  uint1 done         ::= (counter == 0);
  uint8 counter_next ::= done ? 0 : counter + 1;
  always {
    counter = counter_next;
    out     = ~ done;
  }
}

