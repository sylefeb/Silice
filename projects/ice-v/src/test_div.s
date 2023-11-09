.globl _start

_start:

  addi  t1, zero, 123
  addi  t2, zero,-10
  div   t3, t1, t2
  rem   t3, t1, t2
  divu  t3, t1, t2
  remu  t3, t1, t2

jal _start
