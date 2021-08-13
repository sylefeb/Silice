.equ Leds, 0b010000000000

.globl _start

_start:

  addi  t1, zero, 0x0f
loop1:
  addi  t1,t1,-1
  bne   t1,zero,loop1

  addi  t0, zero, 0x3
  sw    t0, Leds(zero)

  addi  t1, zero, 0x0f
loop2:
  addi  t1,t1,-1
  bne   t1,zero,loop2

  addi  t0, zero, 0xC
  sw    t0, Leds(zero)

jal _start
