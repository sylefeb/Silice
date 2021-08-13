.globl _start

_start:

  rdcycle t3
  beq   t3,zero,4
  addi  t0, zero, 33
  slli  t2, t0, 19
  srli  t0, t2, 19
  j     0x18
