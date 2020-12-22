MEMORY
{
   ram (rwx) : ORIGIN = 0x2000000, LENGTH = 0x1000000 /* remember to change crt0 for stack init as well */
}

ENTRY(_start)

SECTIONS {
  .text 0x2000000 : { 
        crt0.o (.text) 
        *(.text) 
        *(.sdata)
        *(.srodata)
        *(.rodata)
        *(.rodata.str1.4)        
        *(.data)
  } >ram 
}
