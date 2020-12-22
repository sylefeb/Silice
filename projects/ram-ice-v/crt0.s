.text
.global _start
.type _start, @function

_start:
   la sp, 0x100000
   call main
   unimp
