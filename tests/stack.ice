algorithm main(output uint8 led)
{

  subroutine bla(output uint8 a)
  {
     a = 15;     
  }

  subroutine foo(output uint8 a,calls bla)
  {
     (a) <- bla <- ();
     (a) <- bla <- ();
  }
  
  subroutine bar(output uint8 a)
  {
     a = 13;  
  }


  // (led) <- bar <- ();  // no stack
  (led) <- foo <- ();  // stack (nested sub call)
++:
  (led) <- bla <- ();
++:  
  led = 5;
}