.text
.global _start
.type _start, @function

_start:
   # load a different stack start 
   # depending on which CPU is running
   rdcycle a5
   andi a5,a5,1
   bnez a5,cpu1
   li sp,0xFFFC
   j done
cpu1:   
   li sp,0xFBFC # leaves 1024 bytes for CPU0
done:   
   call main
   tail exit

.global exit
.type  exit, @function
exit:
   j exit
   ret
