/* from https://raw.githubusercontent.com/YosysHQ/picorv32/master/picosoc/sections.lds */
/* modified for icev-conveyor */

MEMORY
{
    RAM (xrw)  : ORIGIN = 0x00000000, LENGTH = 0x1000000  /* 16 MB */
}

SECTIONS {
    .text :
    {
        . = ALIGN(4);
        *(.text)           /* .text sections (code) */
        *(.text*)          /* .text* sections (code) */
    } >RAM

    .data :
    {
        . = ALIGN(4);
        *(.rodata)         /* .rodata sections (constants, strings, etc.) */
        *(.rodata*)        /* .rodata* sections (constants, strings, etc.) */
        *(.srodata)        /* .rodata sections (constants, strings, etc.) */
        *(.srodata*)       /* .rodata* sections (constants, strings, etc.) */
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
