DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../../tools/fpga-binutils/mingw32/bin/

../../../bin/silice -f ../../../frameworks/icestick_vga_64rgb.v $1 -o build.v
if [ $? -gt 0 ]; then
    exit
fi

yosys -p 'synth_ice40 -top top -json build.json' build.v
nextpnr-ice40 --hx1k --json build.json --pcf ../../../frameworks/icestick.pcf --asc build.asc
icepack build.asc build.bin
iceprog build.bin
