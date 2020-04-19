DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../../tools/fpga-binutils/mingw32/bin/

../../../bin/silice -f ../../../frameworks/icarus_bare.v $1 -o testicarus.v
iverilog -o testicarus testicarus.v
vvp testicarus -fst
