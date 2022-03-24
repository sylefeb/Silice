.text
.global _start
.type _start, @function

_start:
   # load a different stack start
   # depending on which CPU is running
   rdcycle a5
   andi a5,a5,1
   bnez a5,cpu1
   # cpu 0 only
   li sp,65532 # end of SPRAM
   j done
cpu1:
   # cpu 1 only
   li sp,61436 # leaves 4096 bytes for CPU0
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
   # init done
done:
   call main
   tail exit

.global exit
.type  exit, @function
exit:
   j exit
   ret
