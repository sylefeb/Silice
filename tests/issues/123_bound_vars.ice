algorithm test(output uint8 o) <autorun> 
{
  uint8 v(0);
  uint6 t := v + 1;
  
  while (1) {
    o = t;
    v = v + 1; // NOTE: Here Icarus and Verilator give different results.
               // This case is constructed to be potentially problematic,
               // since we have t <: v + 1 and o is assigned t /before/
               // v is increased. Which is correct? I am unsure.
               // Icarus considers o is assigned t /before/ v is incremented
               // which makes sense if we consider = assignments are ordered
               // Verilator considers o is assigned t after v is incremented,
               // which makes sense from a circuit point of view as t is a 
               // wire tracking v in cycle, and v is indeed changed.
               //
               // Which one is correct?
               //
               // Note that using t <:: v + 1 desambiguifies, since the value
               // of v at cycle start is then used.
  }
  
}

algorithm main(output uint8 leds)
{
  test tst;
  uint8 c(0);

  while (c != 10) {
    leds = tst.o;
    __display("[%d] tst.o %d",c,tst.o);
    c = c + 1;
  }  
}
