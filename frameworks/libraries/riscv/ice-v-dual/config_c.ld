MEMORY
{
   ram (rwx) : ORIGIN = 0x00000000, LENGTH = MEM_SIZE
}

ENTRY(_start)

SECTIONS {
  .text 0x00000000 : {
        crt0.o (.text*)
        *(.text*)
        *(.sdata*)
        *(.srodata*)
        *(.rodata*)
        *(.rodata.str1.4*)
        *(.data*)
        *(.sbss*)
  } >ram
}
