/* 
  Based on @BrunoLevy01 FemtoRV crt0
  https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV 
*/

.text
.global _start
.type _start, @function

_start:
   li sp,0x1000
   call main
   tail exit

.global exit
.type  exit, @function
exit:
   .word 0
   ret
