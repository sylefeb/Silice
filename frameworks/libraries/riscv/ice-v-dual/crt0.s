.text
.global _start
.type _start, @function

_start:
   # load a different stack start
   # depending on which core is running
   rdcycle a5
   andi a5,a5,1
   bnez a5,core1
   li sp,STACK_START
   nop # keep cores in sync
   j done
core1:
   li   sp,STACK_START
   li   t0,STACK_SIZE
   sub  sp,sp,t0
done:
   call main
   tail exit

.global exit
.type  exit, @function
exit:
   j exit
   ret
