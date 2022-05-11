.text
.global _start
.type _start, @function

_start:
   # load a different stack start
   # depending on which CPU is running
   rdcycle a5
   andi a5,a5,1
   bnez a5,cpu1
   li sp,65532 # end of SPRAM
   j done
cpu1:
   li sp,61436 # leaves 4096 bytes for CPU0
done:
   call main
   tail exit

.global exit
.type  exit, @function
exit:
   j exit
   ret
