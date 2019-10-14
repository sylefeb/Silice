algorithm main()
{
  uint8 a = 0;
  
  goto skip; // cost nothing as algorithm 
             // will directly start at state skip
  
sub:
  a = 2;
  return;
  
skip:

  a = 3;

  call sub;  
  
  a = 4;

  call sub;  

  a = 5;
  
  goto sub;

  a = 6; // never reached, the return in sub will stop the algorithm
  
}
