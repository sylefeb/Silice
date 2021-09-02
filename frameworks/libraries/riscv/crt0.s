.text
.global _start
.type _start, @function

_start:
   li sp,0x0400
   call main
   tail exit

.global exit
.type  exit, @function
exit:
   j exit
   ret
