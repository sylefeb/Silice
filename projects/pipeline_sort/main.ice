
$$N=32

algorithm main(output uint8 leds)
{

  uint8 in_values[$N$] = {
$$for i=0,N-1 do
     $math.random(254)$,
$$end  
  };
  
$$for n=0,N do
  uint8 sorted_$n$    = 255;
  uint8 to_insert_$n$ = uninitialized;
$$end   

  uint8 i = 0;
  while (i<$2*N$) {

    to_insert_0 = in_values[i];
    
    // pipeline
$$for n=0,N-1 do
$$if n > 0 then
    ->
$$end    
    {
      if (to_insert_$n$ < sorted_$n$) {
        to_insert_$n+1$ = sorted_$n$;
        sorted_$n$      = to_insert_$n$;
      } else {
        to_insert_$n+1$ = to_insert_$n$;
      }
    }
$$end

    i = i + 1;
  }
  
  
$$for n=0,N-1 do
   __display("[%d] = %d",$n$,sorted_$n$);
$$end   
}
