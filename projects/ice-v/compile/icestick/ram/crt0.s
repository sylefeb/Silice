.text
.global _start
.type _start, @function

_start:
   lui	sp,0x08  #sp = 0x00800000
   call main
   tail exit

.global exit
.type  exit, @function
exit:
   .word 0
   ret
