.globl _start

_start:

  addi   t1, zero,-123
  addi   t2, zero, 10
  div    t3, t1, t2
  rem    t3, t1, t2
  divu   t3, t1, t2
  remu   t3, t1, t2

  addi   t1, zero,-3
  addi   t2, zero,-5
  mul    t3, t1, t2
  mulh   t3, t1, t2
  mulhsu t3, t1, t2
  mulhu  t3, t1, t2

jal _start
