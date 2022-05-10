/* from https://raw.githubusercontent.com/YosysHQ/picorv32/master/picosoc/sections.lds */
/* modified for icev-conveyor */

MEMORY
{
    ROM (rx)   : ORIGIN = 0x00000000, LENGTH = 0x01000  /* 4 KB */
    RAM (xrw)  : ORIGIN = 0x00001000, LENGTH = 0x01000  /* 4 KB */
}

SECTIONS {
    /* The program code and other data goes into ROM, mapped in a first BRAM */
    .text :
    {
        . = ALIGN(4);
        *(.text)           /* .text sections (code) */
        *(.text*)          /* .text* sections (code) */
        *(.rodata)         /* .rodata sections (constants, strings, etc.) */
        *(.rodata*)        /* .rodata* sections (constants, strings, etc.) */
        *(.srodata)        /* .rodata sections (constants, strings, etc.) */
        *(.srodata*)       /* .rodata* sections (constants, strings, etc.) */
    } >ROM

    /* The initialized data goes into RAM, mapped in a second BRAM */
    .data :
    {
        . = ALIGN(4);
        *(.data)           /* .data sections */
        *(.data*)          /* .data* sections */
        *(.sdata)          /* .sdata sections */
        *(.sdata*)         /* .sdata* sections */
    } >RAM

    /* Uninitialized data section */
    .bss :
    {
        . = ALIGN(4);
        *(.bss)
        *(.bss*)
        *(.sbss)
        *(.sbss*)
        *(COMMON)
    } >RAM

}
