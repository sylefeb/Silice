#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../../bin/:$DIR/../../../tools/fpga-binutils/mingw64/bin/:/c/intelFPGA_lite/19.1/quartus/bin64/

rm build1*

rm -rf db incremental_db output_files

silice  -D YOSYS=true -f ../../../frameworks/de10nano_sdram_vga.v $1 -o build1.v

yosys -p 'synth_intel_alm -family cyclonev -vqm build1.vqm -top SdramVga' build1.v

exit

quartus_map.exe -c project project

quartus_fit.exe -c project project

quartus_asm.exe -c project project
