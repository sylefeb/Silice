DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../../bin/:$DIR/../../../tools/fpga-binutils/mingw32/bin/

rm build* build.fst build.fst.hier
silice -f ../../../frameworks/icarus_oled.v $1 -o build.v

# exit

iverilog -o build build.v
vvp build -fst
