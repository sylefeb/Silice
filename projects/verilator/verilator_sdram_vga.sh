if test -z "$1"
then
  echo "please provide source file name, without extension"
else

u=$(echo "$1" | sed s:/:__:g | tr -d "..")

echo "using directory $1"

mkdir $u
../../bin/silice -f ../../frameworks/verilator_sdram_vga.v -o $u/vga.v $1.ice 
cd $u
verilator -Wno-PINMISSING -Wno-WIDTH -O3 -cc vga.v --top-module vga
cd obj_dir
make -f Vvga.mk
make -f Vvga.mk ../../../../frameworks/verilator/verilator_vga.o verilated.o
g++ -O3 ../../../../frameworks/verilator/verilator_vga.o verilated.o Vvga__ALL.a ../../../../frameworks/verilator/libverilator_silice.a -o ../../test_$u
cd ..
cd ..

fi
