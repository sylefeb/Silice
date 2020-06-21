.equ Leds, 0x400

.globl _start

_start:

  addi  t0, zero, 0x3
  sw    t0, Leds(zero)
