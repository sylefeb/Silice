algorithm main(output int8 led)
{
  // uint a = 0;
  
  subroutine test(output uint8 c,input uint8 d,reads a):
    c = a + d;
  return;

  call test(b,d);

/*
  alg test(a:> b,c :> d, <:auto:> );

  $display("hello world",a,b,c);

  if (!r0 && !r1 && !r2 && !r3 && !r4 && !r5 && !r6) {
  }
  if (a === b) {    
  } else { if (a == b) {    
  } }

  if (a !== b) {    
  } else { if (a != b) {    
  } }

  b = !b ;

  c = a ~ b;
  c = a ^ b;
  c = a ^~ b;
  c = a ~^ b;
  c = ~ b; 
  c = a ~ ~ b;

  if (a && b || c) {  
  }

  c = a & 3;

  a = &a;
  a = |a;
  a = ~|a;
  a = ~&a;
  a = ~^a;
  a = ^~a;
  
  b = b << 2;
  b = b <<< 3;
  b = b >> 2;
  b = b >>> 3;
  
  a = {1b1,3b101,2hFF} + 53;

    done:
  goto done;

 done2 :
  goto done2;

  switch ({r0,r1}) {
    case 2b00: {
	
	}
    case 2b01: {
	
	}
	case 2b10: {
	
	}
	default: {
	
	}
  }
*/
}
