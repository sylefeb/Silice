.text
.global _start
.type _start, @function

_start:
   li sp,STACK_START
   call main
   tail exit

.global exit
.type  exit, @function
exit:
   j exit
   ret
