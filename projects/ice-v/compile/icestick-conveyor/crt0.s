.text
.global _start
.type _start, @function

_start:
   li sp,0x1800   # end of RAM
   # init done
   call main   # let's roll! (core1)
   tail exit

.global exit
.type  exit, @function
exit:
   j exit
   ret
