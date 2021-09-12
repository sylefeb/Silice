.text
.global _start
.type _start, @function

_start:
   li sp,0x1800
   call main
   tail exit

.global exit
.type  exit, @function
exit:
   .word 0
   ret
