# Building for the de10nano board (Altera CycloneV)

## Basic

```
silice -f ../../../frameworks/de10nano_basic.v -o basic/basic.v <source.ice>
```

## With VGA and SDRAM

```
silice -f ../../../frameworks/de10nano_sdram_vga.v -o sdramvga/SdramVga.v <source.ice>
```

Open the project with Quartus, build, program, enjoy!
