MEMORY
{
   ram (rwx) : ORIGIN = 0x0000004, LENGTH = 0x1000000
   /*                           | avoids a jump to addr 0 after boot
                                  which the compiler does not accept */
}

ENTRY(_start)

SECTIONS {
  .text 0x0000004 : { 
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
