.text
.global _start
.type _start, @function

_start: 
   la sp, after /* this is a hack to push the code away                                   */
   j after      /* so that the boot loader is at the end of the BRAM cache space          */
   .skip 29696  /* it will load code at the start of the BRAM cache, not overriding self! */
after:   
   call main
   .word 0
