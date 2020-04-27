DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../../tools/fpga-binutils/mingw32/bin/

rm build* icarus.fst icarus.fst.hier
../../../bin/silice -f ../../../frameworks/icarus_vga.v $1 -o build.v
iverilog -o build build.v
vvp build -fst
