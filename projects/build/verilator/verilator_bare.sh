#!/bin/bash
if test -z "$1"
then
  echo "please provide source file name"
else

u=$(echo "$1" | sed s:/:__:g | tr -d ".")

echo "using directory $u"

mkdir $u
../../../bin/silice -f ../../../frameworks/verilator_bare.v -o $u/bare.v $1
cd $u
verilator -Wno-PINMISSING -Wno-WIDTH -O3 -cc bare.v --top-module bare
cd obj_dir
make -f Vbare.mk
make -f Vbare.mk ../../../../../frameworks/verilator/verilator_bare.o verilated.o
g++ -O3 ../../../../../frameworks/verilator/verilator_bare.o verilated.o Vbare__ALL.a ../../../../../frameworks/verilator/libverilator_silice.a -o ../../test_$u
cd ..
cd ..

fi
