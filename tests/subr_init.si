algorithm main(output uint8 leds)
{
  uint24 cycle(0);
  uint24 last(0);
 /*
  subroutine wait1()
  {
    uint24 count = uninitialized;
    count = 0;
    while (count != 16) {
      count = count + 1;
    }
  }
*/
  subroutine wait2()
  {
    uint24 count = 0;
    while (count != 16) {
      count = count + 1;
    }
  }

  always_after{ cycle = cycle + 1; }

  __display("start %d",cycle);
  last = cycle;
  () <- wait2 <- ();
  __display("elapsed (2) %d",cycle-last);
  last = cycle;
  () <- wait2 <- ();
  __display("elapsed (2) %d",cycle-last);
  last = cycle;
  () <- wait2 <- ();
  __display("elapsed (2) %d",cycle-last);
  last = cycle;
/*
  __display("start %d",cycle);
  last = cycle;
  () <- wait1 <- ();
  __display("elapsed (1) %d",cycle-last);
  last = cycle;
  () <- wait1 <- ();
  __display("elapsed (1) %d",cycle-last);
  last = cycle;
  () <- wait1 <- ();
  __display("elapsed (1) %d",cycle-last);
  last = cycle;
*/
}
