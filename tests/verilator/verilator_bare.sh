if test -z "$1"
then
  echo "please provide source file name, without extension"
else

mkdir $1
../../bin/silice -f ../../frameworks/verilator_bare.v -o $1/bare.v $1.ice 
cd $1
verilator -Wno-PINMISSING -Wno-WIDTH -cc bare.v --profile-cfuncs --top-module bare # -Wno-fatal 
cd obj_dir
make -f Vbare.mk
make -f Vbare.mk ../../../../frameworks/verilator/verilator_bare.o verilated.o
g++ ../../../../frameworks/verilator/verilator_bare.o verilated.o Vbare__ALL.a ../../../../frameworks/verilator/libverilator_silice.a -o ../../test_$1
cd ..
cd ..

fi

