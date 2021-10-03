MEMORY
{
   ram (rwx) : ORIGIN = 0x0020000, LENGTH = 0x1000000
}

ENTRY(_start)

SECTIONS {
  .text 0x0020000 : {
        crt0.o (.text)
        *(.text)
        *(.sdata)
        *(.srodata)
        *(.rodata)
        *(.rodata.str1.4)
        *(.data)
        *(.sbss)
  } >ram 
}
