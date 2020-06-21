.globl _start

_start:

  addi  t0, zero, 33
  addi  t1, t0, -42
  slti  t2, t1, 0
  sltiu t2, t1, 0
  add   t0, t0, t1
  sub   t0, t0, t1
  lui   t2, 1
  jal   t3, label1
  add   t0, zero, zero
label1:
  addi  t0, zero, 1
  addi  t1, zero, 2
  addi  t2, zero, 127
  blt   t0, t1, label2
  addi  t2, zero, 255
label2:
  add   t0, zero, 131
  srli  t1, t0, 5
  add   t0, zero, -131
  srai  t2, t0, 5  
  add   t0, zero, 6
  slli  t2, t0, 5 

  addi  t0, zero, 0x12
  la    t1, mybyte1
  sb    t0, 0(t1)
  
  addi  t1, zero, 0
  lw    t1, mydata
  
  addi  t0, zero, 0x34
  la    t1, mybyte2
  sb    t0, 0(t1)
  
  addi  t1, zero, 0
  lw    t1, mydata

  addi  t0, zero, 0x56
  la    t1, mydata2
  sh    t0, 0(t1)

  addi  t1, zero, 0
  lw    t1, mydata2

  addi  t0, zero, 0x11
  la    t1, myhalf
  sh    t0, 0(t1)

  addi  t1, zero, 0
  lw    t1, mydata3
  
  addi  t0, zero, 0x101
  la    t1, mydata4
  sw    t0, 0(t1)

  addi  t1, zero, 0
  lw    t1, mydata4

mydata:
.byte  0x00
mybyte1:
.byte  0x00
mybyte2:
.byte  0x00
.byte  0x00

mydata2:
.word  0xeeeeffff

mydata3:
.byte  0xaa
.byte  0xaa
myhalf:
.byte  0xbb
.byte  0xbb

mydata4:
.byte  0xff
.byte  0xff
.byte  0xff
.byte  0xff
