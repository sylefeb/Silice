#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../tools/fpga-binutils/mingw32/bin/

source ../../tools/bash/find_riscv.sh

if [[ $RV32IM ]]; then
  riscarch="rv32im"
else
  riscarch="rv32i"
fi

echo "using $ARCH"
echo "targetting $riscarch"

if [ -z "$2" ]; then 
  echo "Adding mylibc"
  $ARCH-gcc -w -O3 -ffunction-sections -fdata-sections -fno-pic -fno-builtin -march=$riscarch -mabi=ilp32 -c -DBLAZE smoke/mylibc/mylibc.c -o build/mylibc.o
  OBJECTS="build/code.o build/div.o build/mylibc.o"
  CPU=0
elif [ "$2" == "--nolibc" -o "$3" == "--nolibc" ]; then
  echo "Skipping mylibc"
  OBJECTS="build/code.o"
  if [ "$3" == "--nolibc" ]; then
    CPU=${2:-0}
  else
    CPU=0
  fi
else
  CPU=${2:-0}  
fi

echo "Compiling for CPU $CPU"

$ARCH-gcc -O3 -ffunction-sections -fdata-sections -fno-pic -fno-builtin -fverbose-asm -fno-unroll-loops -march=$riscarch -mabi=ilp32 -DBLAZE -S $1 -o build/code.s
$ARCH-gcc -O3 -ffunction-sections -fdata-sections -fno-pic -fno-builtin -fno-unroll-loops -march=$riscarch -mabi=ilp32 -DBLAZE -c -o build/code.o $1

$ARCH-as -march=$riscarch -mabi=ilp32 -o build/div.o smoke/mylibc/div.s
$ARCH-as -march=$riscarch -mabi=ilp32 -o crt0.o smoke/crt0.s

rm build/code0.hex 2> /dev/null
rm build/code1.hex 2> /dev/null

$ARCH-ld --gc-sections -m elf32lriscv -b elf32-littleriscv -Tsmoke/config_blaze.ld --no-relax -o build/code.elf $OBJECTS

$ARCH-objcopy -O verilog build/code.elf build/code$CPU.hex

# uncomment to see the actual code, usefull for debugging
# $ARCH-objcopy.exe -O binary build/code.elf build/code.bin
# $ARCH-objdump.exe -D -b binary -m riscv build/code.bin 
