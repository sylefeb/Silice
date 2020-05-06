#!/bin/bash
if test -z "$1"
then
  echo "please provide source file name"
else

if hash make 2>/dev/null; then
  export MAKE=make
else
  export MAKE=mingw32-make  
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../../tools/fpga-binutils/mingw32/bin/

if [[ -z "${VERILATOR_ROOT}" ]]; then
case "$(uname -s)" in
Linux)
unset VERILATOR_ROOT
;;
*)
export VERILATOR_ROOT=$DIR/../../../tools/fpga-binutils/mingw32/
;;
esac
echo "VERILATOR_ROOT is set to ${VERILATOR_ROOT}"
else
echo "VERILATOR_ROOT already defined, using its value"
fi

u=$(echo "$1" | sed s:/:__:g | tr -d ".")

echo "using directory $u"

mkdir $u
../../../bin/silice -f ../../../frameworks/verilator_sdram_vga.v -o $u/vga.v $1 
cd $u
verilator -Wno-PINMISSING -Wno-WIDTH -O3 -cc vga.v --top-module vga
cd obj_dir
$MAKE -f Vvga.mk
$MAKE -f Vvga.mk ../../../../../frameworks/verilator/verilator_vga.o verilated.o
g++ -O3 ../../../../../frameworks/verilator/verilator_vga.o verilated.o Vvga__ALL.a ../../../../../frameworks/verilator/libverilator_silice.a -o ../../test_$u
cd ..
cd ..

fi
