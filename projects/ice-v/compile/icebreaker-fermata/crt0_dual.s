.text
.global _start
.type _start, @function

_start:
   # load a different stack start
   # depending on which core is running
   rdcycle a5
   andi a5,a5,1
   bnez a5,core1
   # core 0 only
   li sp,65528    # end of SPRAM
   li a0,65532    # barrier location
   sw zero, 0(a0) # lower barrier (core0 waits for core1 while it copies into ram)
   j wait
core1:
   # core 1 only
   li sp,61432 # leaves 4096 bytes for core0
   # from https://github.com/YosysHQ/picorv32/blob/master/picosoc/start.s
   # copy data section
   la a0, _sidata
   la a1, _sdata
   la a2, _edata
   bge a1, a2, end_init_data
   loop_init_data:
   lw a3, 0(a0)
   sw a3, 0(a1)
   addi a0, a0, 4
   addi a1, a1, 4
   blt a1, a2, loop_init_data
   end_init_data:
   # zero-init bss section
   la a0, _sbss
   la a1, _ebss
   bge a0, a1, end_init_bss
   loop_init_bss:
   sw zero, 0(a0)
   addi a0, a0, 4
   blt a0, a1, loop_init_bss
   end_init_bss:
   # raise barrier
   li a0,65532 # barrier location
   li a1, 1
   sw a1, 0(a0)
   # init done
   call main   # let's roll! (core1)
   tail exit
wait:
   lw  a1, 0(a0) # read barrier state
   beq a1, zero, wait # if still low, wait
   call main   # let's roll! (core0)
   tail exit

.global exit
.type  exit, @function
exit:
   j exit
   ret
