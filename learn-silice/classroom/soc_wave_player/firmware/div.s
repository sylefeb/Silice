/* from https://github.com/gcc-mirror/gcc/blob/master/libgcc/config/riscv/div.S (modified to compile with as) */

/* Integer division routines for RISC-V.

   Copyright (C) 2016-2020 Free Software Foundation, Inc.

This file is part of GCC.

GCC is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 3, or (at your option) any later
version.

GCC is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

Under Section 7 of GPL version 3, you are granted additional
permissions described in the GCC Runtime Library Exception, version
3.1, as published by the Free Software Foundation.

You should have received a copy of the GNU General Public License and
a copy of the GCC Runtime Library Exception along with this program;
see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see
<http://www.gnu.org/licenses/>.  */

.globl __divsi3
__divsi3:
  bltz  a0, .L10
  bltz  a1, .L11
  /* Since the quotient is positive, fall into __udivdi3.  */

.globl __udivsi3
__udivsi3:
  mv    a2, a1
  mv    a1, a0
  li    a0, -1
  beqz  a2, .L5
  li    a3, 1
  bgeu  a2, a1, .L2
.L1:
  blez  a2, .L2
  slli  a2, a2, 1
  slli  a3, a3, 1
  bgtu  a1, a2, .L1
.L2:
  li    a0, 0
.L3:
  bltu  a1, a2, .L4
  sub   a1, a1, a2
  or    a0, a0, a3
.L4:
  srli  a3, a3, 1
  srli  a2, a2, 1
  bnez  a3, .L3
.L5:
  ret

.globl __umodsi3
__umodsi3:
  /* Call __udivsi3(a0, a1), then return the remainder, which is in a1.  */
  move  t0, ra
  jal   __udivsi3
  move  a0, a1
  jr    t0

  /* Handle negative arguments to __divsi3.  */
.L10:
  neg   a0, a0 
  bgez  a1, .L12      /* Compute __udivsi3(-a0, a1), then negate the result.  */
  neg   a1, a1
  j     __divsi3      /* Compute __udivsi3(-a0, -a1).  */
.L11:                 /* Compute __udivsi3(a0, -a1), then negate the result.  */
  neg   a1, a1
.L12:
  move  t0, ra
  jal   __divsi3
  neg   a0, a0
  jr    t0

.globl __modsi3
__modsi3:
  move   t0, ra
  bltz   a1, .L31
  bltz   a0, .L32
.L30:
  jal    __udivsi3    /* The dividend is not negative.  */
  move   a0, a1
  jr     t0
.L31:
  neg    a1, a1
  bgez   a0, .L30
.L32:
  neg    a0, a0
  jal    __udivsi3    /* The dividend is hella negative.  */
  neg    a0, a1
  jr     t0
