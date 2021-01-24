.text
.global _start
.type _start, @function

_start: 
   la sp, after /* this is a hack to push the code away                      */
   j after      /* and have the stack at the begining, where the cache lies  */
   .skip 29696  /* there is plenty of memory space before, so no risk there  */
after:   
   call main
   .word 0
